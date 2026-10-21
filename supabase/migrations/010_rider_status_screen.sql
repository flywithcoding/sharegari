-- =============================================================================
-- ShareGari — Migration 010: Rider Status Screen Support
-- =============================================================================
-- Sections:
--   A. Enum addition: 'driver_assigned' to group_status
--   B. View: my_group_co_riders  (first-name-only, RLS-scoped)
--   C. Function: cancel_ride_request(uuid) — smart cancel with group cascade
-- =============================================================================


-- ── A. Enum addition ──────────────────────────────────────────────────────

-- 'driver_assigned' sits between 'pending_driver' (group formed, no driver yet)
-- and 'confirmed' (driver accepted). Step 9 will populate this.
do $$ begin
  alter type public.group_status add value if not exists 'driver_assigned'
    after 'pending_driver';
exception when duplicate_object then null; end $$;


-- ── B. View: my_group_co_riders ───────────────────────────────────────────
-- Returns first-name-only co-rider info for any group the current rider is in.
-- RLS is enforced here via auth.uid() — each rider sees ONLY their own group's
-- co-riders, and gets NO phone, email, or full name.
--
-- Columns returned:
--   group_id        — the shared group
--   request_id      — the co-rider's request (NOT their user id)
--   first_name      — left(name, position(' ' in name)-1) or full name if no space
--   pickup_order    — for displaying pick-up sequence
--   dropoff_order
--   fare            — each co-rider's locked fare (visible for transparency)
--
-- Usage: SELECT * FROM my_group_co_riders WHERE group_id = $1
create or replace view public.my_group_co_riders
  with (security_invoker = true)  -- runs as the calling user; respects RLS
as
select
  gm.group_id,
  gm.request_id,
  -- First name only: take text before the first space; fall back to full name
  case
    when position(' ' in u.name) > 0
    then left(u.name, position(' ' in u.name) - 1)
    else u.name
  end                     as first_name,
  gm.pickup_order,
  gm.dropoff_order,
  gm.fare
from public.group_members gm
join public.ride_requests  rr on rr.id   = gm.request_id
join public.users          u  on u.id    = rr.rider_id
where
  -- Caller must be a member of this group
  gm.group_id in (
    select gm2.group_id
    from   public.group_members gm2
    join   public.ride_requests rr2 on rr2.id = gm2.request_id
    where  rr2.rider_id = auth.uid()
  );

comment on view public.my_group_co_riders is
  'First-name-only co-rider view. security_invoker = true means the caller''s '
  'RLS applies — riders see only their own group, never phone/email.';


-- ── C. cancel_ride_request(request_id) ───────────────────────────────────
-- Smart cancel: handles both pre-group (searching) and post-group (matched)
-- states with the correct cascade behaviour.
--
-- Rules:
--   1. The calling rider must own the request.
--   2. If status is 'searching' or 'pending': cancel immediately (no fee).
--   3. If status is 'matched':
--      a. Mark the group_member cancelled.
--      b. Count remaining non-cancelled members in the group.
--      c. If remaining < 2: cancel the whole group; put remaining
--         requests back to 'searching' so they can be re-matched.
--      d. If remaining >= 2: leave the group active (other riders unaffected).
--   4. Any other status: raise an exception (can't cancel in-progress trip).
--
-- Returns jsonb: {cancelled: true, group_dissolved: bool}
create or replace function public.cancel_ride_request(p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request        record;
  v_group_id       uuid;
  v_remaining      int;
  v_group_dissolved boolean := false;
begin
  -- ── 1. Load and validate the request ────────────────────────────────
  select * into v_request
    from public.ride_requests
   where id = p_request_id;

  if not found then
    raise exception 'Request not found: %', p_request_id;
  end if;

  -- Caller must own the request (SECURITY DEFINER bypasses RLS,
  -- so we enforce ownership explicitly).
  if v_request.rider_id <> auth.uid() then
    raise exception 'Permission denied';
  end if;

  -- ── 2. Cancel while still searching ────────────────────────────────
  if v_request.status in ('searching', 'pending') then
    update public.ride_requests
       set status = 'cancelled', updated_at = now()
     where id = p_request_id;

    return jsonb_build_object('cancelled', true, 'group_dissolved', false);
  end if;

  -- ── 3. Cancel a matched request (group cascade) ─────────────────────
  if v_request.status = 'matched' then
    -- Find the group this request belongs to
    select gm.group_id into v_group_id
      from public.group_members gm
     where gm.request_id = p_request_id
       and gm.status <> 'cancelled'
     limit 1;

    if v_group_id is null then
      -- No active member row; just cancel the request itself
      update public.ride_requests
         set status = 'cancelled', updated_at = now()
       where id = p_request_id;
      return jsonb_build_object('cancelled', true, 'group_dissolved', false);
    end if;

    -- a. Mark this member cancelled
    update public.group_members
       set status = 'cancelled', updated_at = now()
     where request_id = p_request_id
       and group_id   = v_group_id;

    -- Mark this request cancelled
    update public.ride_requests
       set status = 'cancelled', updated_at = now()
     where id = p_request_id;

    -- b. Count remaining non-cancelled members
    select count(*) into v_remaining
      from public.group_members
     where group_id = v_group_id
       and status <> 'cancelled';

    -- c. If group falls below 2 riders, dissolve it
    if v_remaining < 2 then
      -- Cancel the group
      update public.ride_groups
         set status = 'cancelled', updated_at = now()
       where id = v_group_id;

      -- Put remaining active members' requests back to 'searching'
      update public.ride_requests rr
         set status = 'searching', updated_at = now()
        from public.group_members gm
       where gm.group_id   = v_group_id
         and gm.request_id = rr.id
         and gm.status     <> 'cancelled';  -- leave the cancelled ones alone

      -- Also cancel their group_member rows so they don't confuse the engine
      update public.group_members
         set status = 'cancelled', updated_at = now()
       where group_id = v_group_id
         and status   <> 'cancelled';

      v_group_dissolved := true;
    end if;

    return jsonb_build_object('cancelled', true, 'group_dissolved', v_group_dissolved);
  end if;

  -- ── 4. Can't cancel any other status ────────────────────────────────
  raise exception
    'Cannot cancel a request with status "%". '
    'Contact support if you need to cancel an in-progress trip.',
    v_request.status;
end;
$$;

comment on function public.cancel_ride_request(uuid) is
  'Smart cancel: free while searching; after group formed, dissolves group '
  'if remaining riders < 2 and requeues them as searching. '
  'Caller must own the request (enforced inside the function).';

-- Grant execute to authenticated users (they still need to own the request)
grant execute on function public.cancel_ride_request(uuid)
  to authenticated;
