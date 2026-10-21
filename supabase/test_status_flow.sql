-- =============================================================================
-- ShareGari — Test Status Flow
-- =============================================================================
-- HOW TO USE:
--   1. Run ONLY the SELECT at the top (Step 1) to find a group_id.
--   2. Copy the UUID from the result.
--   3. Paste it into each UPDATE below (replace 'YOUR-GROUP-ID-HERE').
--   4. Run each UPDATE one at a time while watching the RideStatusScreen.
--
-- The UPDATE statements are ALL commented out — you must uncomment and
-- fill in the UUID before running them.
-- =============================================================================


-- ── Step 1: Find a test group (run this first) ───────────────────────────────
-- Run this query, copy a group_id, paste it below.
select
  rg.id                        as group_id,
  rg.status,
  rg.depart_at,
  rg.fare_total,
  (select count(*) from public.group_members gm
   where gm.group_id = rg.id and gm.status <> 'cancelled') as rider_count
from public.ride_groups rg
order by rg.created_at desc
limit 5;
-- ↑ Copy the group_id UUID from the row you want to test.
-- Paste it in place of YOUR-GROUP-ID-HERE in the statements below.


-- ── Step 2: pending_driver → driver_assigned ─────────────────────────────────
-- Uncomment and fill in the UUID, then run.
-- update public.ride_groups
--   set status     = 'driver_assigned',
--       updated_at = now()
-- where id = 'YOUR-GROUP-ID-HERE';


-- ── Step 3: driver_assigned → confirmed ──────────────────────────────────────
-- update public.ride_groups
--   set status     = 'confirmed',
--       updated_at = now()
-- where id = 'YOUR-GROUP-ID-HERE';


-- ── Step 4: confirmed → in_progress ─────────────────────────────────────────
-- update public.ride_groups
--   set status     = 'in_progress',
--       updated_at = now()
-- where id = 'YOUR-GROUP-ID-HERE';

-- Mark the first rider as picked up (optional):
-- update public.group_members
--   set status = 'picked_up', picked_up_at = now(), updated_at = now()
-- where group_id = 'YOUR-GROUP-ID-HERE'
--   and pickup_order = 1;


-- ── Step 5: in_progress → completed ─────────────────────────────────────────
-- update public.ride_groups
--   set status     = 'completed',
--       updated_at = now()
-- where id = 'YOUR-GROUP-ID-HERE';

-- Mark all members dropped off:
-- update public.group_members
--   set status = 'dropped_off', dropped_off_at = now(), updated_at = now()
-- where group_id = 'YOUR-GROUP-ID-HERE';


-- ── Bonus: test cancel while searching ──────────────────────────────────────
-- Find a searching request_id from ride_requests, then:
-- select cancel_ride_request('YOUR-REQUEST-ID-HERE');


-- ── Bonus: test cancel after group formed ───────────────────────────────────
-- select cancel_ride_request('YOUR-REQUEST-ID-HERE');


-- ── Bonus: test expiry ───────────────────────────────────────────────────────
-- update public.ride_requests
--   set depart_at = now() + interval '5 minutes'
-- where id = 'YOUR-REQUEST-ID-HERE';
-- select run_matching();


-- ── Reset: restore group for re-testing ──────────────────────────────────────
-- update public.ride_groups
--   set status     = 'pending_driver',
--       driver_id  = null,
--       updated_at = now()
-- where id = 'YOUR-GROUP-ID-HERE';
--
-- update public.group_members
--   set status         = 'waiting',
--       picked_up_at   = null,
--       dropped_off_at = null,
--       updated_at     = now()
-- where group_id = 'YOUR-GROUP-ID-HERE';
