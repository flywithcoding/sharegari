-- =============================================================================
-- ShareGari — Migration 009: Fix run_matching() — replace uuid_generate_v4()
-- =============================================================================
-- Problem:
--   The uuid-ossp extension's uuid_generate_v4() was not available at runtime
--   (the extension may not be enabled, or is not in the function's search_path).
--
-- Fix:
--   Replace uuid_generate_v4() with gen_random_uuid(), which is a built-in
--   PostgreSQL 13+ function that needs no extension.
--
--   This is a CREATE OR REPLACE of the full run_matching() body; no schema
--   changes are needed.
-- =============================================================================

create or replace function public.run_matching()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  cfg              record;
  req              record;
  candidate        record;
  already_matched  uuid[];
  batch            uuid[];
  new_group_id     uuid;
  n_riders         int;
  i                int;
  mem_request_id   uuid;
  straight_km      double precision;
  route_km         double precision;
  route_min        double precision;
  raw_car_fare     double precision;
  car_fare         double precision;
  per_rider_fare   double precision;
  fare_total_val   numeric(10,2);
  groups_formed    int := 0;
  riders_matched   int := 0;
  riders_expired   int := 0;
begin
  -- ── 1. Load config ──────────────────────────────────────────────────────
  select * into cfg from public.pricing_config where id = 1;
  if not found then
    return jsonb_build_object('error', 'pricing_config row not found');
  end if;

  -- ── 2. Expire stale requests ────────────────────────────────────────────
  update public.ride_requests
    set status     = 'expired',
        updated_at = now()
    where status    = 'searching'
      and depart_at <= now() + (cfg.expire_before_min || ' minutes')::interval;

  get diagnostics riders_expired = row_count;

  -- ── 3. Iterate over eligible requests ───────────────────────────────────
  already_matched := '{}';

  for req in
    select id, rider_id, pickup_geo, drop_geo, depart_at, window_min
      from public.ride_requests
     where status    = 'searching'
       and depart_at >  now() + (cfg.expire_before_min  || ' minutes')::interval
       and depart_at <= now() + (cfg.matching_window_min || ' minutes')::interval
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
         and c.id        <> all(already_matched)
         and c.id        <> all(batch)
         and c.rider_id  <> req.rider_id
         and (req.depart_at - (req.window_min || ' minutes')::interval)
               <= (c.depart_at + (c.window_min || ' minutes')::interval)
         and (req.depart_at + (req.window_min || ' minutes')::interval)
               >= (c.depart_at - (c.window_min || ' minutes')::interval)
         and st_dwithin(req.pickup_geo::geography, c.pickup_geo::geography,
                        cfg.max_pickup_radius_m)
         and st_dwithin(req.drop_geo::geography, c.drop_geo::geography,
                        cfg.max_dropoff_radius_m)
         and c.depart_at >  now() + (cfg.expire_before_min  || ' minutes')::interval
         and c.depart_at <= now() + (cfg.matching_window_min || ' minutes')::interval
       order by st_distance(req.pickup_geo::geography, c.pickup_geo::geography)
         for update skip locked
       limit 3
    loop
      batch := batch || candidate.id;
      exit when array_length(batch, 1) = 4;
    end loop;

    n_riders := array_length(batch, 1);
    continue when n_riders < 2;

    -- ── 5. Compute fare ────────────────────────────────────────────────────
    select st_distance(
             req.pickup_geo::geography,
             r.drop_geo::geography
           ) / 1000.0
      into straight_km
      from public.ride_requests r
     where r.id = batch[array_upper(batch, 1)];

    route_km  := coalesce(straight_km, 1.0) * 1.30;
    route_min := route_km / 30.0 * 60.0;

    raw_car_fare := cfg.base_fare_bdt
                  + cfg.per_km_rate_bdt  * route_km
                  + cfg.per_min_rate_bdt * route_min;

    car_fare := greatest(raw_car_fare, cfg.min_fare_bdt);

    per_rider_fare := car_fare / n_riders * (1.0 + cfg.platform_fee_pct);
    per_rider_fare := ceil(per_rider_fare / 5.0) * 5.0;

    fare_total_val := (per_rider_fare * n_riders)::numeric(10,2);

    -- ── 6. Create ride_groups row ──────────────────────────────────────────
    -- gen_random_uuid() is a built-in Postgres 13+ function; no extension needed.
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
        i,
        i + n_riders,
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
  'ShareGari matching engine. Groups ''searching'' ride_requests by time window '
  'and PostGIS geography proximity. Call with SELECT run_matching(); '
  'Schedule every minute with pg_cron (Pro plan) or an Edge Function timer.';
