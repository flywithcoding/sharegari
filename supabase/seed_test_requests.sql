-- =============================================================================
-- ShareGari — Test Seed: 10 Ride Requests for Matching Engine Testing
-- =============================================================================
-- Run this AFTER running all migrations (supabase db push).
--
-- Test scenario:
--   Requests 1-4: Uttara → Motijheel, all close together → should form 1 group of 4
--   Requests 5-6: Mirpur 10 → Gulshan 1, close pair    → should form 1 group of 2
--   Requests 7-8: Dhanmondi → Farmgate, close pair     → should form 1 group of 2
--   Request  9:   Chittagong (far away)                 → should NOT match
--   Request 10:   Departure > 60 min window             → should NOT match
--
-- NOTE: The handle_new_user() trigger fires on auth.users INSERT and creates
-- a public.users row automatically. We pass name and phone in raw_user_meta_data
-- so the trigger picks them up. The public.users INSERT below is a safety net
-- with ON CONFLICT DO NOTHING.
-- =============================================================================

-- ── Step 1: Fake auth.users rows ─────────────────────────────────────────
-- raw_user_meta_data carries name and phone so the trigger writes them.
insert into auth.users (
  id, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_user_meta_data
)
values
  ('00000000-0000-0000-0000-000000000001', 'rider1@test.sharegari.com',
   crypt('Test1234!', gen_salt('bf')), now(), now(), now(),
   '{"name":"Test Rider 1","phone":"+8801111111001"}'::jsonb),

  ('00000000-0000-0000-0000-000000000002', 'rider2@test.sharegari.com',
   crypt('Test1234!', gen_salt('bf')), now(), now(), now(),
   '{"name":"Test Rider 2","phone":"+8801111111002"}'::jsonb),

  ('00000000-0000-0000-0000-000000000003', 'rider3@test.sharegari.com',
   crypt('Test1234!', gen_salt('bf')), now(), now(), now(),
   '{"name":"Test Rider 3","phone":"+8801111111003"}'::jsonb),

  ('00000000-0000-0000-0000-000000000004', 'rider4@test.sharegari.com',
   crypt('Test1234!', gen_salt('bf')), now(), now(), now(),
   '{"name":"Test Rider 4","phone":"+8801111111004"}'::jsonb),

  ('00000000-0000-0000-0000-000000000005', 'rider5@test.sharegari.com',
   crypt('Test1234!', gen_salt('bf')), now(), now(), now(),
   '{"name":"Test Rider 5","phone":"+8801111111005"}'::jsonb),

  ('00000000-0000-0000-0000-000000000006', 'rider6@test.sharegari.com',
   crypt('Test1234!', gen_salt('bf')), now(), now(), now(),
   '{"name":"Test Rider 6","phone":"+8801111111006"}'::jsonb),

  ('00000000-0000-0000-0000-000000000007', 'rider7@test.sharegari.com',
   crypt('Test1234!', gen_salt('bf')), now(), now(), now(),
   '{"name":"Test Rider 7","phone":"+8801111111007"}'::jsonb),

  ('00000000-0000-0000-0000-000000000008', 'rider8@test.sharegari.com',
   crypt('Test1234!', gen_salt('bf')), now(), now(), now(),
   '{"name":"Test Rider 8","phone":"+8801111111008"}'::jsonb),

  ('00000000-0000-0000-0000-000000000009', 'rider9@test.sharegari.com',
   crypt('Test1234!', gen_salt('bf')), now(), now(), now(),
   '{"name":"Test Rider 9","phone":"+8801111111009"}'::jsonb),

  ('00000000-0000-0000-0000-000000000010', 'rider10@test.sharegari.com',
   crypt('Test1234!', gen_salt('bf')), now(), now(), now(),
   '{"name":"Test Rider 10","phone":"+8801111111010"}'::jsonb)
on conflict (id) do nothing;

-- ── Step 2: public.users safety net ──────────────────────────────────────
-- The trigger already created these rows (above). This insert is idempotent
-- in case the trigger ran before migration 008 (nullable phone fix).
insert into public.users (id, name, phone, role, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000001', 'Test Rider 1',  '+8801111111001', 'rider', now(), now()),
  ('00000000-0000-0000-0000-000000000002', 'Test Rider 2',  '+8801111111002', 'rider', now(), now()),
  ('00000000-0000-0000-0000-000000000003', 'Test Rider 3',  '+8801111111003', 'rider', now(), now()),
  ('00000000-0000-0000-0000-000000000004', 'Test Rider 4',  '+8801111111004', 'rider', now(), now()),
  ('00000000-0000-0000-0000-000000000005', 'Test Rider 5',  '+8801111111005', 'rider', now(), now()),
  ('00000000-0000-0000-0000-000000000006', 'Test Rider 6',  '+8801111111006', 'rider', now(), now()),
  ('00000000-0000-0000-0000-000000000007', 'Test Rider 7',  '+8801111111007', 'rider', now(), now()),
  ('00000000-0000-0000-0000-000000000008', 'Test Rider 8',  '+8801111111008', 'rider', now(), now()),
  ('00000000-0000-0000-0000-000000000009', 'Test Rider 9',  '+8801111111009', 'rider', now(), now()),
  ('00000000-0000-0000-0000-000000000010', 'Test Rider 10', '+8801111111010', 'rider', now(), now())
on conflict (id) do update
  set name  = excluded.name,
      phone = excluded.phone;


-- ── Step 3: Ride requests ─────────────────────────────────────────────────
-- Departure: ~30 minutes from now (inside the 60-min matching window,
-- above the 15-min expiry threshold).
-- Geography: SRID=4326;POINT(longitude latitude)

-- ── Group A: Uttara → Motijheel (4 riders — should form a group of 4) ────
-- All pickups within ~400 m; drop-offs within ~500 m.
insert into public.ride_requests
  (rider_id, pickup_geo, pickup_address, drop_geo, drop_address,
   depart_at, window_min, status, estimated_solo_fare, estimated_share_fare)
values
  ('00000000-0000-0000-0000-000000000001',
   'SRID=4326;POINT(90.3988 23.8701)', 'Uttara Sector 7, Dhaka',
   'SRID=4326;POINT(90.4226 23.7279)', 'Motijheel C/A, Dhaka',
   now() + interval '30 minutes', 15, 'searching', 350, 110),

  ('00000000-0000-0000-0000-000000000002',
   'SRID=4326;POINT(90.3975 23.8715)', 'Uttara Sector 6, Dhaka',
   'SRID=4326;POINT(90.4233 23.7271)', 'Motijheel, Dhaka',
   now() + interval '32 minutes', 10, 'searching', 345, 110),

  ('00000000-0000-0000-0000-000000000003',
   'SRID=4326;POINT(90.3995 23.8695)', 'Uttara Sector 7 (North), Dhaka',
   'SRID=4326;POINT(90.4219 23.7285)', 'Motijheel (East), Dhaka',
   now() + interval '28 minutes', 20, 'searching', 355, 110),

  ('00000000-0000-0000-0000-000000000004',
   'SRID=4326;POINT(90.4010 23.8720)', 'Uttara Sector 8, Dhaka',
   'SRID=4326;POINT(90.4240 23.7260)', 'Motijheel (West), Dhaka',
   now() + interval '35 minutes', 15, 'searching', 360, 110);

-- ── Group B: Mirpur 10 → Gulshan 1 (2 riders — should form a group of 2) ─
insert into public.ride_requests
  (rider_id, pickup_geo, pickup_address, drop_geo, drop_address,
   depart_at, window_min, status, estimated_solo_fare, estimated_share_fare)
values
  ('00000000-0000-0000-0000-000000000005',
   'SRID=4326;POINT(90.3650 23.8041)', 'Mirpur 10 Roundabout, Dhaka',
   'SRID=4326;POINT(90.4152 23.7805)', 'Gulshan 1 Circle, Dhaka',
   now() + interval '25 minutes', 15, 'searching', 220, 140),

  ('00000000-0000-0000-0000-000000000006',
   'SRID=4326;POINT(90.3668 23.8055)', 'Mirpur 10 (West Gate), Dhaka',
   'SRID=4326;POINT(90.4138 23.7818)', 'Gulshan 1 (South), Dhaka',
   now() + interval '27 minutes', 20, 'searching', 215, 135);

-- ── Group C: Dhanmondi → Farmgate (2 riders — should form a group of 2) ──
insert into public.ride_requests
  (rider_id, pickup_geo, pickup_address, drop_geo, drop_address,
   depart_at, window_min, status, estimated_solo_fare, estimated_share_fare)
values
  ('00000000-0000-0000-0000-000000000007',
   'SRID=4326;POINT(90.3713 23.7461)', 'Dhanmondi 27, Dhaka',
   'SRID=4326;POINT(90.3932 23.7587)', 'Farmgate, Dhaka',
   now() + interval '30 minutes', 10, 'searching', 120, 75),

  ('00000000-0000-0000-0000-000000000008',
   'SRID=4326;POINT(90.3752 23.7510)', 'Dhanmondi 15, Dhaka',
   'SRID=4326;POINT(90.3945 23.7575)', 'Farmgate (East), Dhaka',
   now() + interval '33 minutes', 15, 'searching', 115, 70);

-- ── No-match: Chittagong (far from all Dhaka requests) ───────────────────
insert into public.ride_requests
  (rider_id, pickup_geo, pickup_address, drop_geo, drop_address,
   depart_at, window_min, status, estimated_solo_fare, estimated_share_fare)
values
  ('00000000-0000-0000-0000-000000000009',
   'SRID=4326;POINT(91.8333 22.3569)', 'GEC Circle, Chittagong',
   'SRID=4326;POINT(91.8236 22.3320)', 'Agrabad, Chittagong',
   now() + interval '30 minutes', 15, 'searching', 180, 100);

-- ── No-match: departure 90 minutes away (outside 60-min window) ──────────
insert into public.ride_requests
  (rider_id, pickup_geo, pickup_address, drop_geo, drop_address,
   depart_at, window_min, status, estimated_solo_fare, estimated_share_fare)
values
  ('00000000-0000-0000-0000-000000000010',
   'SRID=4326;POINT(90.3988 23.8701)', 'Uttara Sector 7, Dhaka',
   'SRID=4326;POINT(90.4226 23.7279)', 'Motijheel C/A, Dhaka',
   now() + interval '90 minutes', 15, 'searching', 350, 110);


-- ── Optional cleanup (uncomment when done testing) ────────────────────────
-- delete from public.ride_requests where rider_id like '00000000-0000-0000-0000-%';
-- delete from public.users        where id          like '00000000-0000-0000-0000-%';
-- delete from auth.users          where id::text    like '00000000-0000-0000-0000-%';
