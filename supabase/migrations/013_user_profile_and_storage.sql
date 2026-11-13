-- =============================================================================
-- ShareGari — Migration 013: Profile Columns, RLS & Avatars Storage Bucket
-- =============================================================================
-- 1. Ensure public.users table has:
--      - full_name (alias or synchronized with name)
--      - phone (text)
--      - avatar_url (text)
--      - role (user_role enum)
--      - rating (numeric(3,2) default 5.00)
--      - created_at (timestamptz default now())
--      - updated_at (timestamptz default now())
--
-- 2. RLS for public.users:
--      - User can SELECT only their own row (auth.uid() = id).
--      - User can UPDATE only their own row (auth.uid() = id).
--      - Co-riders see first name & rating via existing my_group_co_riders view.
--
-- 3. Storage bucket: "avatars" (public):
--      - Anyone can SELECT (read) avatar files.
--      - Authenticated users can INSERT/UPDATE/DELETE only files in their own folder:
--        i.e. (storage.foldername(name))[1] = auth.uid()::text
-- =============================================================================

-- ── 1. Columns on public.users ──────────────────────────────────────────────

-- Add avatar_url if not exists
alter table public.users
  add column if not exists avatar_url text;

comment on column public.users.avatar_url is
  'Public URL of the user profile photo stored in Supabase Storage.';

-- Ensure rating has default 5.00 and check constraint
alter table public.users
  alter column rating set default 5.00;

-- Add full_name column if missing, and sync with name
alter table public.users
  add column if not exists full_name text;

comment on column public.users.full_name is
  'Full display name of the user, synchronized with name.';

-- Populate full_name from name where null
update public.users
  set full_name = name
  where full_name is null and name is not null;

-- Populate name from full_name where null
update public.users
  set name = full_name
  where name is null and full_name is not null;

-- Trigger to keep name and full_name in sync automatically
create or replace function public.sync_user_full_name()
returns trigger
language plpgsql
as $$
begin
  if new.full_name is not null and (old.full_name is null or new.full_name <> old.full_name) then
    new.name := new.full_name;
  elsif new.name is not null and (old.name is null or new.name <> old.name) then
    new.full_name := new.name;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sync_user_full_name on public.users;
create trigger trg_sync_user_full_name
  before insert or update on public.users
  for each row execute function public.sync_user_full_name();


-- ── 2. Update handle_new_user() trigger to populate full_name & avatar_url ──

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_phone text;
  v_name  text;
begin
  v_phone := nullif(
    coalesce(new.raw_user_meta_data->>'phone', ''),
    ''
  );
  v_name := coalesce(
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'name',
    split_part(new.email, '@', 1)
  );

  insert into public.users (id, name, full_name, phone, role, avatar_url)
  values (
    new.id,
    v_name,
    v_name,
    v_phone,
    coalesce(new.raw_user_meta_data->>'role', 'rider')::public.user_role,
    new.raw_user_meta_data->>'avatar_url'
  )
  on conflict (id) do update
    set full_name = coalesce(excluded.full_name, users.full_name),
        name      = coalesce(excluded.name, users.name),
        phone     = coalesce(excluded.phone, users.phone),
        updated_at = now();

  return new;
end;
$$;


-- ── 3. Confirm RLS on public.users ──────────────────────────────────────────

alter table public.users enable row level security;

-- Ensure select & update policies are strictly auth.uid() = id
drop policy if exists "users: read own row" on public.users;
create policy "users: read own row"
  on public.users for select
  using (auth.uid() = id);

drop policy if exists "users: update own row" on public.users;
create policy "users: update own row"
  on public.users for update
  using (auth.uid() = id)
  with check (auth.uid() = id);


-- ── 4. Supabase Storage: "avatars" bucket ───────────────────────────────────

-- Create the bucket if it does not exist
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  2097152, -- 2MB max
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
  set public = true,
      file_size_limit = 2097152,
      allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

-- Storage RLS:
-- 1) Anyone can read avatar files
drop policy if exists "avatars: public read" on storage.objects;
create policy "avatars: public read"
  on storage.objects for select
  using (bucket_id = 'avatars');

-- 2) User can upload into their own folder: <uid>/<filename>
drop policy if exists "avatars: user upload own folder" on storage.objects;
create policy "avatars: user upload own folder"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- 3) User can update files in their own folder
drop policy if exists "avatars: user update own folder" on storage.objects;
create policy "avatars: user update own folder"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- 4) User can delete files in their own folder
drop policy if exists "avatars: user delete own folder" on storage.objects;
create policy "avatars: user delete own folder"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
