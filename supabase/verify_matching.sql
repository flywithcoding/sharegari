-- =============================================================================
-- ShareGari — Matching Engine Verification Queries
-- Run in the Supabase SQL editor AFTER:
--   1. supabase db push (applies all migrations)
--   2. seed_test_requests.sql
--   3. SELECT run_matching();   ← query 1 below does this
-- =============================================================================

-- ── 1. Run the matching engine ────────────────────────────────────────────
select run_matching();


-- ── 2. Summary: what did the engine do? ──────────────────────────────────
select
  status,
  count(*) as request_count
from public.ride_requests
where rider_id::text like '00000000-0000-0000-0000-%'
group by status
order by status;
-- Expected:
--   matched   | 8   (riders 1-8)
--   searching | 2   (riders 9, 10 — no match / outside window)


-- ── 3. Groups formed ──────────────────────────────────────────────────────
select
  rg.id,
  rg.status,
  rg.depart_at,
  rg.fare_total,
  rg.platform_fee,
  (rg.route_json->>'route_km')::float  as route_km,
  (rg.route_json->>'n_riders')::int    as n_riders,
  rg.created_at
from public.ride_groups rg
order by rg.created_at desc;
-- Expected: 3 groups
--   Group A: n_riders=4, status='pending_driver'
--   Group B: n_riders=2, status='pending_driver'
--   Group C: n_riders=2, status='pending_driver'


-- ── 4. Group members with fares ───────────────────────────────────────────
select
  rg.id                           as group_id,
  gm.pickup_order,
  gm.dropoff_order,
  gm.fare                         as per_rider_fare_bdt,
  gm.status                       as member_status,
  rr.pickup_address,
  rr.drop_address,
  rr.depart_at
from public.group_members gm
join public.ride_groups   rg on rg.id = gm.group_id
join public.ride_requests rr on rr.id = gm.request_id
order by rg.created_at, gm.pickup_order;
-- Expected:
--   Each group_member row has a fare (multiple of 5, > 0)
--   Fares for group A (4 riders) should be roughly 1/4 of car_fare * 1.10
--   Fares for groups B & C (2 riders) higher per-person


-- ── 5. Fare sanity check — all fares divisible by 5 ─────────────────────
select
  gm.id,
  gm.fare,
  (gm.fare::int % 5) as remainder  -- must be 0
from public.group_members gm
join public.ride_requests rr on rr.id = gm.request_id
where rr.rider_id::text like '00000000-0000-0000-0000-%';
-- Expected: all rows have remainder = 0


-- ── 6. No-match verification ─────────────────────────────────────────────
select
  rr.rider_id,
  rr.pickup_address,
  rr.status,
  rr.depart_at
from public.ride_requests rr
where rr.rider_id in (
  '00000000-0000-0000-0000-000000000009'::uuid,
  '00000000-0000-0000-0000-000000000010'::uuid
);
-- Expected:
--   Rider 9  (Chittagong) → status = 'searching' (no Dhaka riders nearby)
--   Rider 10 (90-min dep) → status = 'searching' (outside matching window)


-- ── 7. Pickup proximity check (sanity) ───────────────────────────────────
-- Confirm riders in Group A are all within 1.5 km of each other.
select
  a.pickup_address as from_address,
  b.pickup_address as to_address,
  round(st_distance(a.pickup_geo::geography, b.pickup_geo::geography)::numeric) as dist_m
from public.ride_requests a
join public.ride_requests b
  on  a.rider_id < b.rider_id
where a.rider_id in (
  '00000000-0000-0000-0000-000000000001'::uuid,
  '00000000-0000-0000-0000-000000000002'::uuid,
  '00000000-0000-0000-0000-000000000003'::uuid,
  '00000000-0000-0000-0000-000000000004'::uuid
)
and b.rider_id in (
  '00000000-0000-0000-0000-000000000001'::uuid,
  '00000000-0000-0000-0000-000000000002'::uuid,
  '00000000-0000-0000-0000-000000000003'::uuid,
  '00000000-0000-0000-0000-000000000004'::uuid
)
order by dist_m;
-- Expected: all distances < 1500 m


-- ── 8. Clean up test data (run when done testing) ────────────────────────
-- UNCOMMENT to reset:
-- delete from public.ride_requests
--   where rider_id::text like '00000000-0000-0000-0000-%';
-- delete from public.users
--   where id::text like '00000000-0000-0000-0000-%';
-- delete from auth.users
--   where id::text like '00000000-0000-0000-0000-%';
