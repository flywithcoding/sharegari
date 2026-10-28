-- =============================================================================
-- ShareGari — Migration 011: Update Matching Engine (Lookahead + Date Separation)
-- =============================================================================
-- Changes:
--   1. Schema: Add `matching_lookahead_days` (default 7) to `pricing_config`.
--   2. Function: Update `run_matching()`:
--      - Expire unmatched requests whose departure is <= now() + 15 min
--        (depart_at - 15 minutes <= now()).
--      - Remove 60-minute limit; use configurable lookahead (default 7 days).
--      - Compatible candidates:
--          * Full depart_at timestamps overlap within their windows (different dates never match)
--          * Pickups within cfg.max_pickup_radius_m
--          * Drop-offs within cfg.max_dropoff_radius_m
--          * Both requests are status = 'searching'
--          * From different riders (c.rider_id <> req.rider_id)
--      - Maintain group size of 2 to 4.
--      - Maintain concurrency safety with FOR UPDATE SKIP LOCKED.
-- =============================================================================

-- ── 1. Schema changes ─────────────────────────────────────────────────────

alter table public.pricing_config
  add column if not exists matching_lookahead_days int not null default 7;

comment on column public.pricing_config.matching_lookahead_days is
  'Matching engine lookahead window in days (default 7). Requests departing within this window are considered for matching.';

update public.pricing_config
  set matching_lookahead_days = 7, updated_at = now()
  where id = 1 and (matching_lookahead_days is null or matching_lookahead_days <> 7);


-- ── 2. Update run_matching() ──────────────────────────────────────────────

create or replace function public.run_matching()
returns jsonb
language plpgsql
security definer          -- bypass RLS so the function can write to all tables
set search_path = public  -- prevent search-path injection
as $$
declare
  cfg              record;
  req              record;
  candidate        record;
  already_matched  uuid[];   -- request ids placed into a group this run
  batch            uuid[];   -- ids for the current candidate group
  new_group_id     uuid;
  n_riders         int;
  i                int;
  mem_request_id   uuid;
  -- Fare computation
  straight_km      double precision;
  route_km         double precision;
  route_min        double precision;
  raw_car_fare     double precision;
  car_fare         double precision;
  per_rider_fare   double precision;
  fare_total_val   numeric(10,2);
  -- Counters
  groups_formed    int := 0;
  riders_matched   int := 0;
  riders_expired   int := 0;
begin
  -- ── 1. Load config ──────────────────────────────────────────────────────
  select * into cfg from public.pricing_config where id = 1;
  if not found then
    return jsonb_build_object('error', 'pricing_config row not found');
  end if;

  -- ── 2. Expire unmatched requests at depart_at minus 15 minutes ──────────
  -- Unmatched 'searching' requests whose departure is within expire_before_min
  -- minutes (or already passed) are marked 'expired'.
  update public.ride_requests
    set status     = 'expired',
        updated_at = now()
    where status    = 'searching'
      and depart_at - (coalesce(cfg.expire_before_min, 15) || ' minutes')::interval <= now();

  get diagnostics riders_expired = row_count;

  -- ── 3. Iterate over eligible requests ───────────────────────────────────
  already_matched := '{}';

  for req in
    select id, rider_id, pickup_geo, drop_geo, depart_at, window_min
      from public.ride_requests
     where status = 'searching'
       -- Must not be expired (> depart_at - 15 min)
       and depart_at - (coalesce(cfg.expire_before_min, 15) || ' minutes')::interval > now()
       -- Within configurable lookahead window (default 7 days)
       and depart_at <= now() + (coalesce(cfg.matching_lookahead_days, 7) || ' days')::interval
     order by depart_at, created_at
       for update skip locked
  loop
    continue when req.id = any(already_matched);

    -- ── 4. Collect compatible candidates ──────────────────────────────────
    batch := array[req.id];

    for candidate in
      select c.id
        from public.ride_requests c
       where c.status    = 'searching'
         and c.id        <> req.id
         and c.id        <> all(already_matched)   -- not in a previous group
         and c.id        <> all(batch)              -- not already in this batch
         and c.rider_id  <> req.rider_id            -- different riders
         -- Time window overlap using full depart_at timestamps (different dates never match)
         and (req.depart_at - (req.window_min || ' minutes')::interval)
               <= (c.depart_at + (c.window_min || ' minutes')::interval)
         and (req.depart_at + (req.window_min || ' minutes')::interval)
               >= (c.depart_at - (c.window_min || ' minutes')::interval)
         -- Pickup proximity (PostGIS geography, sphere metres)
         and st_dwithin(req.pickup_geo::geography, c.pickup_geo::geography,
                        cfg.max_pickup_radius_m)
         -- Drop-off proximity (PostGIS geography, sphere metres)
         and st_dwithin(req.drop_geo::geography, c.drop_geo::geography,
                        cfg.max_dropoff_radius_m)
         -- Candidate must also be unexpired and within lookahead window
         and c.depart_at - (coalesce(cfg.expire_before_min, 15) || ' minutes')::interval > now()
         and c.depart_at <= now() + (coalesce(cfg.matching_lookahead_days, 7) || ' days')::interval
       order by
         st_distance(req.pickup_geo::geography, c.pickup_geo::geography)
         for update skip locked
       limit 3   -- anchor + up to 3 candidates = max group of 4
    loop
      batch := batch || candidate.id;
      exit when array_length(batch, 1) = 4;
    end loop;

    -- Only form a group with 2 to 4 riders.
    n_riders := array_length(batch, 1);
    continue when n_riders < 2;

    -- ── 5. Compute fare ────────────────────────────────────────────────────
    -- Route distance = straight line from anchor pickup to last drop-off * 1.30.
    -- NOTE: Replace with ORS call in Step 10.
    select st_distance(
             req.pickup_geo::geography,
             r.drop_geo::geography
           ) / 1000.0
      into straight_km
      from public.ride_requests r
     where r.id = batch[array_upper(batch, 1)];

    route_km  := coalesce(straight_km, 1.0) * 1.30;
    route_min := route_km / 30.0 * 60.0;  -- assume 30 km/h city average

    raw_car_fare := cfg.base_fare_bdt
                  + cfg.per_km_rate_bdt  * route_km
                  + cfg.per_min_rate_bdt * route_min;

    car_fare := greatest(raw_car_fare, cfg.min_fare_bdt);

    -- Split evenly, add platform fee, round UP to nearest 5 taka.
    per_rider_fare := car_fare / n_riders * (1.0 + cfg.platform_fee_pct);
    per_rider_fare := ceil(per_rider_fare / 5.0) * 5.0;

    fare_total_val := (per_rider_fare * n_riders)::numeric(10,2);

    -- ── 6. Create ride_groups row ──────────────────────────────────────────
    new_group_id := gen_random_uuid();

    insert into public.ride_groups (
      id, status, depart_at,
      fare_total, platform_fee,
      route_json,
      created_at, updated_at
    ) values (
      new_group_id,
      'pending_driver',
      req.depart_at,
      fare_total_val,
      (fare_total_val * cfg.platform_fee_pct / (1.0 + cfg.platform_fee_pct))::numeric(10,2),
      jsonb_build_object(
        'type',      'summary',
        'n_riders',  n_riders,
        'route_km',  round(route_km::numeric, 2),
        'route_min', round(route_min::numeric, 1),
        'note',      'straight-line x 1.30; replace with ORS in Step 10'
      ),
      now(),
      now()
    );

    -- ── 7. Create group_members rows ───────────────────────────────────────
    -- pickup_order  = position in batch (1 = anchor, greedy-NN ordered)
    -- dropoff_order = pickup_order + n_riders (all drop-offs after all pickups)
    for i in 1 .. n_riders loop
      mem_request_id := batch[i];

      insert into public.group_members (
        group_id, request_id, fare,
        pickup_order, dropoff_order,
        status, created_at, updated_at
      ) values (
        new_group_id,
        mem_request_id,
        per_rider_fare::numeric(10,2),
        i,            -- pickup_order:  1 = first pickup
        i + n_riders, -- dropoff_order: n+1 = first drop-off
        'waiting',
        now(),
        now()
      );

      update public.ride_requests
        set status     = 'matched',
            updated_at = now()
        where id = mem_request_id;

      already_matched := already_matched || mem_request_id;
      riders_matched  := riders_matched + 1;
    end loop;

    groups_formed := groups_formed + 1;

  end loop;

  return jsonb_build_object(
    'groups_formed',  groups_formed,
    'riders_matched', riders_matched,
    'riders_expired', riders_expired,
    'ran_at',         now()
  );
end;
$$;

comment on function public.run_matching() is
  'ShareGari matching engine. Groups ''searching'' ride_requests by full timestamp window '
  '(dates must overlap) and PostGIS geography proximity. Lookahead configurable via '
  'pricing_config.matching_lookahead_days (default 7 days). Call with SELECT run_matching();';

