-- =============================================================================
-- ShareGari — Migration 002: Auth trigger
--
-- Creates a Postgres trigger on auth.users that auto-inserts a matching
-- public.users profile row on every new signup.
--
-- Run this AFTER migration 001.
-- Paste into Supabase SQL Editor and click Run.
-- =============================================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer          -- runs with owner privileges, bypasses RLS
set search_path = public  -- prevents search_path injection attacks
as $$
begin
  insert into public.users (id, name, phone, role)
  values (
    new.id,
    -- Name from signup metadata, fallback to email prefix
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    -- Phone from metadata (rider fills it on signup), fallback to empty
    coalesce(new.raw_user_meta_data->>'phone', ''),
    -- Role from metadata, fallback to 'rider'
    coalesce(new.raw_user_meta_data->>'role', 'rider')::public.user_role
  );
  return new;
end;
$$;

-- Attach trigger to auth.users (drop first so re-running is safe)
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
