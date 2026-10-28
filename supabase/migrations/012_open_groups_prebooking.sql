-- =============================================================================
-- ShareGari — Migration 012: Open Groups for Pre-booking & Cutoff Management
-- =============================================================================
-- Requirements:
--   1. Enum: Add 'open' to group_status (new groups start as 'open').
--   2. Schema:
--      - Add group_cutoff_minutes (default 120) to pricing_config.
--      - Add cutoff_at and current_fare to ride_groups.
--   3. run_matching():
--      - New groups start as 'open'.
--      - Each run adds compatible 'searching' requests to existing 'open' groups
--        with < 4 riders, verifying pickup and drop-off distances hold for ALL
--        existing members.
--      - Recalculates per-rider fare as current_fare (car_fare / riders rounded
--        up to nearest 5 taka), which can ONLY go down.
--      - Replaces 15-min expiry with group_cutoff_minutes (default 120 min before depart_at).
--      - At depart_at minus cutoff:
--          * Open groups with >= 2 riders -> transition to 'pending_driver' (fare locked).
--          * Open groups left with < 2 riders -> 'cancelled' and request -> 'expired'.
--      - Maintains FOR UPDATE SKIP LOCKED on all queries.
-- =============================================================================

-- ── 1. Enum addition ──────────────────────────────────────────────────────

do $$ begin
  alter type public.group_status add value if not exists 'open' before 'pending_driver';
exception when duplicate_object then null; end $$;


-- ── 2. Schema changes ─────────────────────────────────────────────────────

-- Add group_cutoff_minutes to pricing_config (default 120 minutes = 2 hours)
alter table public.pricing_config
  add column if not exists group_cutoff_minutes int not null default 120;

comment on column public.pricing_config.group_cutoff_minutes is
  'Minutes before depart_at when open groups lock fare and transition to pending_driver (default 120). Unmatched searching requests also expire at this cutoff.';

update public.pricing_config
  set group_cutoff_minutes = 120, updated_at = now()
  where id = 1 and (group_cutoff_minutes is null or group_cutoff_minutes <> 120);

-- Add cutoff_at and current_fare to ride_groups
alter table public.ride_groups
  add column if not exists cutoff_at timestamptz,
  add column if not exists current_fare numeric(10,2);

comment on column public.ride_groups.cutoff_at is
  'Timestamp when open group transitions to pending_driver and locks fare (depart_at minus group_cutoff_minutes).';

comment on column public.ride_groups.current_fare is
  'Current per-rider fare for open groups (can only decrease as more riders join).';


-- ── 3. Update run_matching() ──────────────────────────────────────────────

create or replace function public.run_matching()
returns jsonb
language plpgsql
security definer          -- bypass RLS so the function can write to all tables
set search_path = public  -- prevent search-path injection
as $$
declare
  cfg                 record;
  cutoff_min          int;
  lookahead_days      int;
  max_pickup_m        int;
  max_dropoff_m       int;

  -- Processing open groups at cutoff
  open_grp            record;
  grp_member_count    int;
  groups_confirmed    int := 0;
  groups_cancelled    int := 0;

  -- Adding riders to existing open groups
  active_grp          record;
  cand                record;
  n_existing          int;

  -- Forming new groups
  req                 record;
  candidate           record;
  batch               uuid[];
  new_group_id        uuid;
  n_riders            int;
  i                   int;
  mem_request_id      uuid;

  -- Fare computation
  straight_km         double precision;
  route_km            double precision;
  route_min           double precision;
  raw_car_fare        double precision;
  car_fare            double precision;
  per_rider_fare      double precision;
  fare_total_val      numeric(10,2);
  v_cutoff_at         timestamptz;

  -- Tracking
  already_matched     uuid[] := '{}';

  -- Counters
  groups_formed       int := 0;
  riders_matched      int := 0;
  riders_added        int := 0;
  riders_expired      int := 0;
begin
  -- ── 1. Load config ──────────────────────────────────────────────────────
  select * into cfg from public.pricing_config where id = 1;
  if not found then
    return jsonb_build_object('error', 'pricing_config row not found');
  end if;

  cutoff_min     := coalesce(cfg.group_cutoff_minutes, 120);
  lookahead_days := coalesce(cfg.matching_lookahead_days, 7);
  max_pickup_m   := cfg.max_pickup_radius_m;
  max_dropoff_m  := cfg.max_dropoff_radius_m;

  -- ── 2. Process open groups reaching cutoff ───────────────────────────────
  -- At depart_at minus cutoff:
  --   * Groups with >= 2 riders: set to 'pending_driver' and lock fare.
  --   * Groups left with < 2 riders: set to 'cancelled' and request to 'expired'.
  for open_grp in
    select id, depart_at
      from public.ride_groups
     where status = 'open'
       and depart_at - (cutoff_min || ' minutes')::interval <= now()
     for update skip locked
  loop
    select count(*) into grp_member_count
      from public.group_members
     where group_id = open_grp.id
       and status <> 'cancelled';

    if grp_member_count >= 2 then
      -- Transition to pending_driver and lock fare
      update public.ride_groups
         set status     = 'pending_driver',
             updated_at = now()
       where id = open_grp.id;

      groups_confirmed := groups_confirmed + 1;
    else
      -- Group left with 1 or 0 riders becomes cancelled, requests expire
      update public.ride_groups
         set status     = 'cancelled',
             updated_at = now()
       where id = open_grp.id;

      update public.ride_requests
         set status     = 'expired',
             updated_at = now()
       where id in (
         select request_id
           from public.group_members
          where group_id = open_grp.id
       )
       and status = 'matched';

      update public.group_members
         set status     = 'cancelled',
             updated_at = now()
       where group_id = open_grp.id;

      groups_cancelled := groups_cancelled + 1;
    end if;
  end loop;

  -- ── 3. Expire unmatched searching requests at cutoff ────────────────────
  -- Replaced 15-minute expiry with cutoff (depart_at - cutoff_minutes <= now).
  update public.ride_requests
     set status     = 'expired',
         updated_at = now()
   where status    = 'searching'
     and depart_at - (cutoff_min || ' minutes')::interval <= now();

  get diagnostics riders_expired = row_count;

  -- ── 4. Add compatible 'searching' requests to existing 'open' groups ───
  -- Only open groups with < 4 riders and before cutoff can accept new riders.
  for active_grp in
    select rg.id, rg.depart_at, rg.fare_total, rg.current_fare
      from public.ride_groups rg
     where rg.status = 'open'
       and rg.depart_at - (cutoff_min || ' minutes')::interval > now()
       and rg.depart_at <= now() + (lookahead_days || ' days')::interval
       and (
         select count(*)
           from public.group_members gm
          where gm.group_id = rg.id
            and gm.status <> 'cancelled'
       ) < 4
     order by rg.depart_at, rg.created_at
     for update skip locked
  loop
    -- Count current members
    select count(*) into n_existing
      from public.group_members
     where group_id = active_grp.id
       and status <> 'cancelled';

    continue when n_existing >= 4;

    -- Find compatible searching requests for this open group.
    -- Candidate must satisfy:
    --   1. status = 'searching'
    --   2. Not already in a group or this run's batch
    --   3. From a different rider than any existing member in this group
    --   4. Full depart_at timestamp overlaps with every existing member's window
    --   5. Distance limits hold for ALL existing members (pickups <= max_pickup, dropoffs <= max_dropoff)
    --   6. Candidate not expired and within lookahead window
    for cand in
      select c.id, c.rider_id, c.pickup_geo, c.drop_geo, c.depart_at, c.window_min
        from public.ride_requests c
       where c.status    = 'searching'
         and c.id        <> all(already_matched)
         -- Different rider from all existing members
         and c.rider_id not in (
           select rr.rider_id
             from public.group_members gm
             join public.ride_requests rr on rr.id = gm.request_id
            where gm.group_id = active_grp.id
              and gm.status <> 'cancelled'
         )
         -- Time window overlap with all existing members
         and not exists (
           select 1
             from public.group_members gm
             join public.ride_requests mr on mr.id = gm.request_id
            where gm.group_id = active_grp.id
              and gm.status <> 'cancelled'
              and (
                (mr.depart_at - (mr.window_min || ' minutes')::interval > c.depart_at + (c.window_min || ' minutes')::interval)
                or
                (mr.depart_at + (mr.window_min || ' minutes')::interval < c.depart_at - (c.window_min || ' minutes')::interval)
              )
         )
         -- Distance limits must hold for ALL existing members
         and not exists (
           select 1
             from public.group_members gm
             join public.ride_requests mr on mr.id = gm.request_id
            where gm.group_id = active_grp.id
              and gm.status <> 'cancelled'
              and (
                not st_dwithin(mr.pickup_geo::geography, c.pickup_geo::geography, max_pickup_m)
                or
                not st_dwithin(mr.drop_geo::geography, c.drop_geo::geography, max_dropoff_m)
              )
         )
         -- Candidate not expired and within lookahead window
         and c.depart_at - (cutoff_min || ' minutes')::interval > now()
         and c.depart_at <= now() + (lookahead_days || ' days')::interval
       order by
         st_distance(
           c.pickup_geo::geography,
           (select rr.pickup_geo::geography
              from public.group_members gm
              join public.ride_requests rr on rr.id = gm.request_id
             where gm.group_id = active_grp.id
             order by gm.pickup_order asc
             limit 1)
         )
       for update skip locked
       limit (4 - n_existing)
    loop
      n_existing := n_existing + 1;

      -- Add candidate to group_members
      insert into public.group_members (
        group_id, request_id, fare,
        pickup_order, dropoff_order,
        status, created_at, updated_at
      ) values (
        active_grp.id,
        cand.id,
        coalesce(active_grp.current_fare, 50.00),
        n_existing,
        n_existing + n_existing,
        'waiting',
        now(),
        now()
      );

      update public.ride_requests
         set status     = 'matched',
             updated_at = now()
       where id = cand.id;

      already_matched := already_matched || cand.id;
      riders_matched  := riders_matched + 1;
      riders_added    := riders_added + 1;

      -- Re-normalize dropoff orders
      update public.group_members
         set dropoff_order = pickup_order + n_existing,
             updated_at    = now()
       where group_id = active_grp.id
         and status <> 'cancelled';

      -- Recalculate route distance & fare for the enlarged group
      select st_distance(
               (select rr.pickup_geo::geography
                  from public.group_members gm
                  join public.ride_requests rr on rr.id = gm.request_id
                 where gm.group_id = active_grp.id
                 order by gm.pickup_order asc limit 1),
               (select rr.drop_geo::geography
                  from public.group_members gm
                  join public.ride_requests rr on rr.id = gm.request_id
                 where gm.group_id = active_grp.id
                 order by gm.pickup_order desc limit 1)
             ) / 1000.0
        into straight_km;

      route_km  := coalesce(straight_km, 1.0) * 1.30;
      route_min := route_km / 30.0 * 60.0;

      raw_car_fare := cfg.base_fare_bdt
                    + cfg.per_km_rate_bdt  * route_km
                    + cfg.per_min_rate_bdt * route_min;
      car_fare := greatest(raw_car_fare, cfg.min_fare_bdt);

      per_rider_fare := car_fare / n_existing * (1.0 + cfg.platform_fee_pct);
      per_rider_fare := ceil(per_rider_fare / 5.0) * 5.0;

      -- "which can only go down": update each member's fare to LEAST(existing, new)
      update public.group_members
         set fare       = least(fare, per_rider_fare::numeric(10,2)),
             updated_at = now()
       where group_id = active_grp.id
         and status <> 'cancelled';

      fare_total_val := (per_rider_fare * n_existing)::numeric(10,2);

      update public.ride_groups
         set current_fare = per_rider_fare::numeric(10,2),
             fare_total   = fare_total_val,
             platform_fee = (fare_total_val * cfg.platform_fee_pct / (1.0 + cfg.platform_fee_pct))::numeric(10,2),
             route_json   = jsonb_build_object(
               'type',      'summary',
               'n_riders',  n_existing,
               'route_km',  round(route_km::numeric, 2),
               'route_min', round(route_min::numeric, 1),
               'note',      'straight-line x 1.30; open group updated'
             ),
             updated_at   = now()
       where id = active_grp.id;

      exit when n_existing >= 4;
    end loop;
  end loop;

  -- ── 5. Form new 'open' groups from remaining 'searching' requests ────────
  for req in
    select id, rider_id, pickup_geo, drop_geo, depart_at, window_min
      from public.ride_requests
     where status    = 'searching'
       and id        <> all(already_matched)
       and depart_at - (cutoff_min || ' minutes')::interval > now()
       and depart_at <= now() + (lookahead_days || ' days')::interval
     order by depart_at, created_at
     for update skip locked
  loop
    continue when req.id = any(already_matched);

    batch := array[req.id];

    for candidate in
      select c.id
        from public.ride_requests c
       where c.status    = 'searching'
         and c.id        <> req.id
         and c.id        <> all(already_matched)
         and c.id        <> all(batch)
         and c.rider_id  <> req.rider_id
         -- Full depart_at timestamps overlap within their windows
         and (req.depart_at - (req.window_min || ' minutes')::interval)
               <= (c.depart_at + (c.window_min || ' minutes')::interval)
         and (req.depart_at + (req.window_min || ' minutes')::interval)
               >= (c.depart_at - (c.window_min || ' minutes')::interval)
         -- Pickup & drop-off proximity
         and st_dwithin(req.pickup_geo::geography, c.pickup_geo::geography, max_pickup_m)
         and st_dwithin(req.drop_geo::geography, c.drop_geo::geography, max_dropoff_m)
         and c.depart_at - (cutoff_min || ' minutes')::interval > now()
         and c.depart_at <= now() + (lookahead_days || ' days')::interval
       order by
         st_distance(req.pickup_geo::geography, c.pickup_geo::geography)
         for update skip locked
       limit 3
    loop
      batch := batch || candidate.id;
      exit when array_length(batch, 1) = 4;
    end loop;

    n_riders := array_length(batch, 1);
    continue when n_riders < 2;

    -- Compute fare for new group
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
    v_cutoff_at    := req.depart_at - (cutoff_min || ' minutes')::interval;
    new_group_id   := gen_random_uuid();

    -- A new group starts as 'open'
    insert into public.ride_groups (
      id, status, depart_at, cutoff_at,
      current_fare, fare_total, platform_fee,
      route_json,
      created_at, updated_at
    ) values (
      new_group_id,
      'open',
      req.depart_at,
      v_cutoff_at,
      per_rider_fare::numeric(10,2),
      fare_total_val,
      (fare_total_val * cfg.platform_fee_pct / (1.0 + cfg.platform_fee_pct))::numeric(10,2),
      jsonb_build_object(
        'type',      'summary',
        'n_riders',  n_riders,
        'route_km',  round(route_km::numeric, 2),
        'route_min', round(route_min::numeric, 1),
        'note',      'straight-line x 1.30; open group created'
      ),
      now(),
      now()
    );

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
    'groups_formed',    groups_formed,
    'riders_matched',   riders_matched,
    'riders_added',     riders_added,
    'groups_confirmed', groups_confirmed,
    'groups_cancelled', groups_cancelled,
    'riders_expired',   riders_expired,
    'ran_at',           now()
  );
end;
$$;

comment on function public.run_matching() is
  'ShareGari matching engine with open groups for pre-booking. New groups start as '
  '''open''. Subsequent runs add compatible riders to open groups (< 4 riders) and '
  'recalculate current_fare (can only decrease). At depart_at - cutoff, groups transition '
  'to ''pending_driver'' (or ''cancelled'' if < 2 riders).';

