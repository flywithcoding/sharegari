-- =============================================================================
-- ShareGari — Matching Engine Verification Queries
-- Run in the Supabase SQL editor AFTER:
--   1. supabase db push (applies all migrations, including 011)
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
--   matched   | 8   (riders 1-8: across 4 separate 2-rider groups)
--   searching | 2   (riders 9, 10: rider 9 geo-isolated; rider 10 cross-date solo)


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
order by rg.depart_at, rg.created_at;
-- Expected: 4 groups of 2 riders
--   Group 1: Uttara → Motijheel on Date 1 (n_riders=2)
--   Group 2: Mirpur → Gulshan on Date 1 (n_riders=2)
--   Group 3: Dhanmondi → Farmgate on Date 1 (n_riders=2)
--   Group 4: Uttara → Motijheel on Date 2 (+1 day, n_riders=2)


-- ── 4. Cross-date isolation proof ─────────────────────────────────────────
-- Prove that no group contains riders from multiple dates:
select
  gm.group_id,
  count(distinct date(rr.depart_at)) as distinct_dates,
  min(rr.depart_at) as earliest_depart,
  max(rr.depart_at) as latest_depart,
  count(*) as member_count
from public.group_members gm
join public.ride_requests rr on rr.id = gm.request_id
where rr.rider_id::text like '00000000-0000-0000-0000-%'
group by gm.group_id;
-- Expected: distinct_dates = 1 for EVERY group. No group mixes Date 1 and Date 2.


-- ── 5. Group members with fares & departure timestamps ───────────────────
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
order by rg.depart_at, gm.pickup_order;


-- ── 6. Fare sanity check — all fares divisible by 5 ─────────────────────
select
  gm.id,
  gm.fare,
  (gm.fare::int % 5) as remainder  -- must be 0
from public.group_members gm
join public.ride_requests rr on rr.id = gm.request_id
where rr.rider_id::text like '00000000-0000-0000-0000-%';
-- Expected: all rows have remainder = 0


-- ── 7. No-match verification ─────────────────────────────────────────────
select
  rr.rider_id,
  rr.pickup_address,
  rr.drop_address,
  rr.status,
  rr.depart_at
from public.ride_requests rr
where rr.rider_id in (
  '00000000-0000-0000-0000-000000000009'::uuid,
  '00000000-0000-0000-0000-000000000010'::uuid
);
-- Expected:
--   Rider 9  (Chittagong)           → status = 'searching' (no Dhaka riders nearby)
--   Rider 10 (Dhanmondi, Date 2)    → status = 'searching' (does NOT merge into Date 1 Group)


-- ── 8. Clean up test data (run when done testing) ────────────────────────
-- UNCOMMENT to reset:
-- delete from public.group_members
--   where request_id in (select id from public.ride_requests where rider_id::text like '00000000-0000-0000-0000-%');
-- delete from public.ride_groups
--   where id not in (select distinct group_id from public.group_members);
-- delete from public.ride_requests
--   where rider_id::text like '00000000-0000-0000-0000-%';
-- delete from public.users
--   where id::text like '00000000-0000-0000-0000-%';
-- delete from auth.users
--   where id::text like '00000000-0000-0000-0000-%';
