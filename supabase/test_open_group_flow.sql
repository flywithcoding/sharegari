-- =============================================================================
-- ShareGari — Test Script: Open Group Lifecycle & Third Rider Price Drop
-- =============================================================================
-- This script proves:
--   1. An initial 2-rider match creates an 'open' group with a current price.
--   2. When a 3rd rider requests a compatible ride later, run_matching() adds
--      them to the existing open group.
--   3. The per-rider fare drops for all existing members and the new member.
--   4. At depart_at minus cutoff (120 min), the open group transitions to
--      'pending_driver' and locks the fare.
--
-- Instructions: Run in the Supabase SQL editor step by step or all at once.
-- =============================================================================

-- ── Step 0: Clean up previous test data ────────────────────────────────────
delete from public.group_members
 where request_id in (
   select id from public.ride_requests
    where rider_id in (
      '00000000-0000-0000-0000-000000000001'::uuid,
      '00000000-0000-0000-0000-000000000002'::uuid,
      '00000000-0000-0000-0000-000000000003'::uuid
    )
 );

delete from public.ride_groups
 where id not in (select distinct group_id from public.group_members);

delete from public.ride_requests
 where rider_id in (
   '00000000-0000-0000-0000-000000000001'::uuid,
   '00000000-0000-0000-0000-000000000002'::uuid,
   '00000000-0000-0000-0000-000000000003'::uuid
 );


-- ── Step 1: Ensure test users exist ───────────────────────────────────────
insert into auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_user_meta_data)
values
  ('00000000-0000-0000-0000-000000000001', 'rider1@test.sharegari.com', crypt('Test1234!', gen_salt('bf')), now(), now(), now(), '{"name":"Abir Rider","phone":"+8801111111001"}'::jsonb),
  ('00000000-0000-0000-0000-000000000002', 'rider2@test.sharegari.com', crypt('Test1234!', gen_salt('bf')), now(), now(), now(), '{"name":"Bilal Rider","phone":"+8801111111002"}'::jsonb),
  ('00000000-0000-0000-0000-000000000003', 'rider3@test.sharegari.com', crypt('Test1234!', gen_salt('bf')), now(), now(), now(), '{"name":"Chad Rider","phone":"+8801111111003"}'::jsonb)
on conflict (id) do nothing;

insert into public.users (id, name, phone, role, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000001', 'Abir Rider',  '+8801111111001', 'rider', now(), now()),
  ('00000000-0000-0000-0000-000000000002', 'Bilal Rider', '+8801111111002', 'rider', now(), now()),
  ('00000000-0000-0000-0000-000000000003', 'Chad Rider',  '+8801111111003', 'rider', now(), now())
on conflict (id) do update set name = excluded.name;


-- ── Step 2: Seed initial 2 riders (departing in 5 hours, well before cutoff) ─
insert into public.ride_requests
  (rider_id, pickup_geo, pickup_address, drop_geo, drop_address,
   depart_at, window_min, status, estimated_solo_fare, estimated_share_fare)
values
  ('00000000-0000-0000-0000-000000000001',
   'SRID=4326;POINT(90.3988 23.8701)', 'Uttara Sector 7, Dhaka',
   'SRID=4326;POINT(90.4226 23.7279)', 'Motijheel C/A, Dhaka',
   now() + interval '5 hours', 15, 'searching', 350, 110),

  ('00000000-0000-0000-0000-000000000002',
   'SRID=4326;POINT(90.3975 23.8715)', 'Uttara Sector 6, Dhaka',
   'SRID=4326;POINT(90.4233 23.7271)', 'Motijheel, Dhaka',
   now() + interval '5 hours 2 minutes', 15, 'searching', 345, 110);


-- ── Step 3: Run matching (Run 1) — forms a new 'open' group of 2 ─────────
select run_matching();

-- Verify: Group starts as 'open' with 2 riders
select
  rg.id as group_id,
  rg.status,
  rg.current_fare as per_rider_price_bdt,
  rg.fare_total,
  (rg.route_json->>'n_riders')::int as riders_in_group,
  to_char(rg.cutoff_at, 'YYYY-MM-DD HH24:MI:SS') as cutoff_time
from public.ride_groups rg
where rg.status = 'open';

-- Verify initial members' fares (2 riders)
select
  gm.group_id,
  u.name,
  gm.pickup_order,
  gm.fare as fare_bdt
from public.group_members gm
join public.ride_requests rr on rr.id = gm.request_id
join public.users u on u.id = rr.rider_id
where gm.group_id in (select id from public.ride_groups where status = 'open')
order by gm.pickup_order;


-- ── Step 4: Third rider requests a ride later on the same route ───────────
insert into public.ride_requests
  (rider_id, pickup_geo, pickup_address, drop_geo, drop_address,
   depart_at, window_min, status, estimated_solo_fare, estimated_share_fare)
values
  ('00000000-0000-0000-0000-000000000003',
   'SRID=4326;POINT(90.3995 23.8695)', 'Uttara Sector 7 (North), Dhaka',
   'SRID=4326;POINT(90.4219 23.7285)', 'Motijheel (East), Dhaka',
   now() + interval '5 hours', 15, 'searching', 355, 110);


-- ── Step 5: Run matching (Run 2) — 3rd rider joins and price drops! ───────
select run_matching();

-- PROOF 1: Group is still 'open', rider count increased to 3, and price dropped!
select
  rg.id as group_id,
  rg.status,
  rg.current_fare as new_per_rider_price_bdt,
  rg.fare_total,
  (rg.route_json->>'n_riders')::int as riders_in_group
from public.ride_groups rg
where rg.status = 'open';

-- PROOF 2: All 3 members now enjoy the lower fare (which only went down)
select
  gm.group_id,
  u.name,
  gm.pickup_order,
  gm.fare as updated_fare_bdt
from public.group_members gm
join public.ride_requests rr on rr.id = gm.request_id
join public.users u on u.id = rr.rider_id
where gm.group_id in (select id from public.ride_groups where status = 'open')
order by gm.pickup_order;


-- ── Step 6: Simulate reaching cutoff — open group locks & becomes pending_driver ──
-- Fast-forward the group's departure to 60 minutes from now (inside the 120-min cutoff)
update public.ride_groups
   set depart_at = now() + interval '60 minutes',
       cutoff_at = now() - interval '60 minutes'
 where status = 'open';

-- Run matching (Run 3) — processes cutoff
select run_matching();

-- PROOF 3: Group transitioned from 'open' to 'pending_driver', fare is locked
select
  rg.id as group_id,
  rg.status,
  rg.current_fare as locked_fare_bdt,
  rg.fare_total
from public.ride_groups rg
where rg.id in (
  select group_id from public.group_members gm
  join public.ride_requests rr on rr.id = gm.request_id
  where rr.rider_id = '00000000-0000-0000-0000-000000000001'::uuid
);

