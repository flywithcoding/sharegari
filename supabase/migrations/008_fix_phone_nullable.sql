-- =============================================================================
-- ShareGari — Migration 008: Fix phone uniqueness for users without a phone
-- =============================================================================
-- Problem:
--   The handle_new_user() trigger uses '' (empty string) as a phone fallback
--   when a new auth.users row has no phone in raw_user_meta_data. When more
--   than one such user exists, the unique constraint on public.users.phone
--   fires with duplicate key ''.
--
-- Fix:
--   1. Relax phone from NOT NULL to nullable.
--      PostgreSQL UNIQUE indexes treat NULLs as distinct, so multiple rows
--      with phone = NULL are allowed.
--   2. Replace the trigger function with one that uses NULL when no phone
--      is provided.
--   3. Fix any existing '' phone rows to NULL.
-- =============================================================================

-- ── 1. Allow NULL phone ───────────────────────────────────────────────────
alter table public.users
  alter column phone drop not null;

comment on column public.users.phone is
  'Rider/driver phone number. NULL until the user verifies their phone. '
  'Unique (NULLs are treated as distinct by the index).';

-- Fix any existing empty-string rows from before this migration.
update public.users
  set phone = null
  where phone = '';


-- ── 2. Replace handle_new_user() with a NULL-safe version ─────────────────
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer          -- runs with owner privileges, bypasses RLS
set search_path = public  -- prevents search_path injection attacks
as $$
declare
  v_phone text;
begin
  -- Use phone from signup metadata; NULL when not supplied.
  -- NULL is stored so multiple phone-less users don't collide on the
  -- unique index (PostgreSQL treats each NULL as distinct).
  v_phone := nullif(
    coalesce(new.raw_user_meta_data->>'phone', ''),
    ''
  );

  insert into public.users (id, name, phone, role)
  values (
    new.id,
    -- Name from signup metadata, fallback to email prefix.
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    v_phone,
    -- Role from metadata, fallback to 'rider'.
    coalesce(new.raw_user_meta_data->>'role', 'rider')::public.user_role
  )
  on conflict (id) do nothing;  -- idempotent: skip if the profile already exists

  return new;
end;
$$;

comment on function public.handle_new_user() is
  'Trigger: auto-creates a public.users profile when a new auth.users row is '
  'inserted. Phone is NULL when not provided at signup; the rider can add it '
  'in the profile screen later.';
