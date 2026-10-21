-- ── Step 6c: Supabase Realtime publication + RLS verification ───────────────
--
-- Problem: Supabase Realtime only streams tables that are added to the
-- `supabase_realtime` publication. The user ran the ALTER by hand; this
-- migration makes it idempotent so a fresh database gets the same setting.
--
-- Tables covered:
--   • ride_requests  — riders watch their own requests for status changes
--   • ride_groups    — Step 7 matching engine will create groups
--   • group_members  — Step 7; riders watch their group membership
--
-- Using DO $$ ... $$ to guard each ALTER so it is safe to run twice
-- (Postgres raises an error if you add a table already in the publication).

do $$
begin
  -- ride_requests
  if not exists (
    select 1
    from   pg_publication_tables
    where  pubname   = 'supabase_realtime'
      and  schemaname = 'public'
      and  tablename  = 'ride_requests'
  ) then
    alter publication supabase_realtime add table public.ride_requests;
  end if;

  -- ride_groups
  if not exists (
    select 1
    from   pg_publication_tables
    where  pubname   = 'supabase_realtime'
      and  schemaname = 'public'
      and  tablename  = 'ride_groups'
  ) then
    alter publication supabase_realtime add table public.ride_groups;
  end if;

  -- group_members
  if not exists (
    select 1
    from   pg_publication_tables
    where  pubname   = 'supabase_realtime'
      and  schemaname = 'public'
      and  tablename  = 'group_members'
  ) then
    alter publication supabase_realtime add table public.group_members;
  end if;
end $$;

-- ── RLS verification ──────────────────────────────────────────────────────
--
-- Confirm the rider SELECT policies exist (they were created in migration 001).
-- This block is documentation-only; no DDL is executed.
--
-- Expected policies on ride_requests (for SELECT):
--   "ride_requests: rider reads own"
--     USING (rider_id = auth.uid())
--
-- Expected policies on ride_groups (for SELECT):
--   "ride_groups: member can read"
--     USING (exists (select 1 from public.group_members gm
--                    where gm.group_id = id and gm.request_id in
--                          (select rr.id from public.ride_requests rr
--                           where rr.rider_id = auth.uid())))
--
-- Expected policies on group_members (for SELECT):
--   "group_members: rider reads own"
--     USING (request_id in (select rr.id from public.ride_requests rr
--                           where rr.rider_id = auth.uid()))
--
-- These policies were already created in 001_initial_schema.sql.
-- Realtime respects RLS — a rider can only receive change events for rows
-- they are allowed to read, so no additional policy changes are needed.
