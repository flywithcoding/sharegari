-- =============================================================================
-- ShareGari — Migration 001: Initial Schema
-- Run this in the Supabase SQL editor (or via supabase db push).
--
-- Sections:
--   0. Extensions
--   1. Custom types (enums)
--   2. Tables
--   3. Indexes
--   4. Row Level Security (RLS) policies
--   5. Seed: pricing_config defaults
-- =============================================================================

-- -----------------------------------------------------------------------
-- 0. Extensions
-- -----------------------------------------------------------------------
create extension if not exists "uuid-ossp";
create extension if not exists "postgis";


-- -----------------------------------------------------------------------
-- 1. Custom types (enums)
-- -----------------------------------------------------------------------

-- User role in the system
create type user_role as enum ('rider', 'driver', 'admin');

-- Driver approval state
create type driver_status as enum ('pending', 'approved', 'suspended');

-- Lifecycle of a ride request
create type request_status as enum (
  'pending',       -- waiting to be matched
  'matched',       -- placed into a ride_group
  'confirmed',     -- group confirmed, driver assigned
  'in_progress',   -- trip underway
  'completed',
  'cancelled',
  'expired'        -- no match found before deadline
);

-- Lifecycle of a ride group
create type group_status as enum (
  'forming',       -- matching engine building the group
  'confirmed',     -- driver accepted
  'in_progress',
  'completed',
  'cancelled'
);

-- Individual member's state inside a group
create type member_status as enum (
  'waiting',
  'picked_up',
  'dropped_off',
  'no_show',
  'cancelled'
);

-- Payment method options
create type payment_method as enum ('cash', 'bkash', 'nagad');

-- Payment transaction state
create type payment_status as enum ('pending', 'completed', 'failed', 'refunded');


-- -----------------------------------------------------------------------
-- 2. Tables
-- -----------------------------------------------------------------------

-- ── 2.1 users ───────────────────────────────────────────────────────────
-- Extends Supabase auth.users (1-to-1 via id).
create table public.users (
  id            uuid primary key references auth.users(id) on delete cascade,
  name          text not null,
  phone         text unique not null,
  role          user_role not null default 'rider',
  fcm_token     text,                       -- Firebase Cloud Messaging device token
  rating        numeric(3,2) not null default 5.00
                  check (rating >= 1 and rating <= 5),
  rating_count  int not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
comment on table public.users is
  'App-level user profile, 1-to-1 with auth.users.';


-- ── 2.2 drivers ─────────────────────────────────────────────────────────
create table public.drivers (
  user_id       uuid primary key references public.users(id) on delete cascade,
  nid           text not null,
  license_no    text not null,
  car_model     text not null,
  plate         text not null unique,
  seat_capacity int not null default 4 check (seat_capacity between 1 and 7),
  status        driver_status not null default 'pending',
  is_online     boolean not null default false,
  -- Real-time location (updated every few seconds while on a trip)
  location      geography(Point, 4326),
  -- Earnings
  payout_account text,                      -- mobile banking number for payouts
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
comment on table public.drivers is
  'Driver profile and vehicle details. Only approved drivers receive groups.';


-- ── 2.3 ride_requests ───────────────────────────────────────────────────
create table public.ride_requests (
  id            uuid primary key default uuid_generate_v4(),
  rider_id      uuid not null references public.users(id) on delete restrict,
  -- Pickup
  pickup_geo    geography(Point, 4326) not null,
  pickup_address text not null,
  -- Drop-off
  drop_geo      geography(Point, 4326) not null,
  drop_address  text not null,
  -- Timing
  depart_at     timestamptz not null,
  window_min    int not null default 10 check (window_min in (10, 15, 20)),
  -- Fare estimate shown to rider before confirming
  estimated_solo_fare  numeric(10,2),
  estimated_share_fare numeric(10,2),
  -- Status
  status        request_status not null default 'pending',
  seats         int not null default 1 check (seats = 1),  -- MVP: 1 seat only
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
comment on table public.ride_requests is
  'A single rider''s request for a shared ride.';


-- ── 2.4 ride_groups ─────────────────────────────────────────────────────
create table public.ride_groups (
  id            uuid primary key default uuid_generate_v4(),
  driver_id     uuid references public.drivers(user_id) on delete set null,
  status        group_status not null default 'forming',
  -- Ordered route computed by the matching engine
  route_json    jsonb,            -- GeoJSON LineString or ordered stop list
  -- Aggregated fare totals
  fare_total    numeric(10,2),    -- sum of all member fares (what driver earns)
  platform_fee  numeric(10,2),    -- platform cut (default 10%)
  depart_at     timestamptz not null,
  -- Driver offer management
  driver_offer_expires_at timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
comment on table public.ride_groups is
  'A matched group of 2–4 riders sharing one car.';


-- ── 2.5 group_members ───────────────────────────────────────────────────
create table public.group_members (
  id              uuid primary key default uuid_generate_v4(),
  group_id        uuid not null references public.ride_groups(id) on delete cascade,
  request_id      uuid not null references public.ride_requests(id) on delete restrict,
  -- Fare split
  fare            numeric(10,2) not null,
  -- Stop ordering (1-based; lower = earlier stop on route)
  pickup_order    int not null,
  dropoff_order   int not null,
  -- Status
  status          member_status not null default 'waiting',
  -- Timestamps for pickup/dropoff events
  picked_up_at    timestamptz,
  dropped_off_at  timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (group_id, request_id)
);
comment on table public.group_members is
  'Junction between ride_groups and ride_requests; holds per-rider fare and stop order.';


-- ── 2.6 payments ────────────────────────────────────────────────────────
create table public.payments (
  id            uuid primary key default uuid_generate_v4(),
  member_id     uuid not null references public.group_members(id) on delete restrict,
  method        payment_method not null,
  amount        numeric(10,2) not null check (amount > 0),
  status        payment_status not null default 'pending',
  provider_ref  text,          -- bKash/Nagad transaction ID or aggregator ref
  paid_at       timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
comment on table public.payments is
  'Payment record for one group_member. One payment per member per trip.';


-- ── 2.7 ratings ─────────────────────────────────────────────────────────
create table public.ratings (
  id            uuid primary key default uuid_generate_v4(),
  group_id      uuid not null references public.ride_groups(id) on delete cascade,
  rater_id      uuid not null references public.users(id) on delete cascade,
  ratee_id      uuid not null references public.users(id) on delete cascade,
  score         int not null check (score between 1 and 5),
  comment       text,
  created_at    timestamptz not null default now(),
  unique (group_id, rater_id, ratee_id)
);
comment on table public.ratings is
  'Mutual ratings after a trip (rider↔driver, rider↔co-rider).';


-- ── 2.8 incidents ───────────────────────────────────────────────────────
create table public.incidents (
  id            uuid primary key default uuid_generate_v4(),
  group_id      uuid references public.ride_groups(id) on delete set null,
  reporter_id   uuid not null references public.users(id) on delete cascade,
  description   text not null,
  resolved      boolean not null default false,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
comment on table public.incidents is
  'SOS alerts and reported issues submitted by riders or drivers.';


-- ── 2.9 pricing_config ──────────────────────────────────────────────────
create table public.pricing_config (
  id                    int primary key default 1
                          check (id = 1),    -- enforce singleton row
  base_fare_bdt         numeric(8,2) not null default 30.00,
  per_km_rate_bdt       numeric(8,2) not null default 18.00,
  sharing_factor        numeric(4,3) not null default 0.700,   -- 70% of solo fare
  platform_fee_pct      numeric(4,3) not null default 0.100,   -- 10%
  max_pickup_radius_m   int          not null default 1500,     -- 1.5 km
  max_dropoff_radius_m  int          not null default 2000,     -- 2 km
  max_detour_minutes    int          not null default 10,
  -- Expire unmatched requests N minutes before departure
  expire_before_min     int          not null default 15,
  -- Small-group pricing cap: never more than this fraction of solo fare
  small_group_fare_cap  numeric(4,3) not null default 0.600,   -- 60%
  updated_at            timestamptz  not null default now()
);
comment on table public.pricing_config is
  'Singleton row holding all tunable pricing and matching parameters.';


-- -----------------------------------------------------------------------
-- 3. Indexes
-- -----------------------------------------------------------------------

-- PostGIS spatial indexes — critical for the matching engine
create index ride_requests_pickup_geo_idx
  on public.ride_requests using gist (pickup_geo);

create index ride_requests_drop_geo_idx
  on public.ride_requests using gist (drop_geo);

create index drivers_location_idx
  on public.drivers using gist (location)
  where location is not null;

-- Query patterns for matching engine and status screens
create index ride_requests_status_depart_idx
  on public.ride_requests (status, depart_at);

create index ride_requests_rider_id_idx
  on public.ride_requests (rider_id);

create index ride_groups_status_depart_idx
  on public.ride_groups (status, depart_at);

create index group_members_group_id_idx
  on public.group_members (group_id);

create index group_members_request_id_idx
  on public.group_members (request_id);

create index payments_member_id_idx
  on public.payments (member_id);

create index ratings_ratee_id_idx
  on public.ratings (ratee_id);


-- -----------------------------------------------------------------------
-- 4. Row Level Security (RLS)
-- -----------------------------------------------------------------------
-- Principle: a user can read/write their own rows only.
-- Drivers additionally see group/member data for their assigned trips.
-- Admin operations are performed server-side via the service_role key;
-- no admin RLS policies are needed here (service_role bypasses RLS).

alter table public.users           enable row level security;
alter table public.drivers         enable row level security;
alter table public.ride_requests   enable row level security;
alter table public.ride_groups     enable row level security;
alter table public.group_members   enable row level security;
alter table public.payments        enable row level security;
alter table public.ratings         enable row level security;
alter table public.incidents       enable row level security;
alter table public.pricing_config  enable row level security;

-- ──── Helper: is the current user a driver? ────────────────────────────
-- Used in several policies below. Inline subquery is cleaner than a fn
-- because it avoids SECURITY DEFINER complexities.

-- ──── 4.1 users ────────────────────────────────────────────────────────

-- Each user can read their own profile
create policy "users: read own row"
  on public.users for select
  using (auth.uid() = id);

-- Each user can update their own profile (not id, role — those are server-side)
create policy "users: update own row"
  on public.users for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- New profile is inserted by the server (auth trigger or Edge Function);
-- disallow client-side insert to prevent role escalation.
create policy "users: insert via service role only"
  on public.users for insert
  with check (false);

create policy "users: no direct delete"
  on public.users for delete
  using (false);

-- ──── 4.2 drivers ──────────────────────────────────────────────────────

-- A driver can read and update their own driver profile
create policy "drivers: read own row"
  on public.drivers for select
  using (auth.uid() = user_id);

create policy "drivers: update own row"
  on public.drivers for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "drivers: insert via service role only"
  on public.drivers for insert
  with check (false);

create policy "drivers: no direct delete"
  on public.drivers for delete
  using (false);

-- ──── 4.3 ride_requests ────────────────────────────────────────────────

-- Riders can read their own requests
create policy "ride_requests: rider reads own"
  on public.ride_requests for select
  using (auth.uid() = rider_id);

-- Riders can insert (create a new request)
create policy "ride_requests: rider inserts own"
  on public.ride_requests for insert
  with check (auth.uid() = rider_id);

-- Riders can update their own pending request (e.g. cancel before match)
create policy "ride_requests: rider updates own pending"
  on public.ride_requests for update
  using (auth.uid() = rider_id and status = 'pending')
  with check (auth.uid() = rider_id);

create policy "ride_requests: no direct delete"
  on public.ride_requests for delete
  using (false);

-- ──── 4.4 ride_groups ──────────────────────────────────────────────────

-- A rider can see a group if they are a member of it
create policy "ride_groups: member can read"
  on public.ride_groups for select
  using (
    exists (
      select 1
      from public.group_members gm
      join public.ride_requests rr on rr.id = gm.request_id
      where gm.group_id = ride_groups.id
        and rr.rider_id = auth.uid()
    )
  );

-- A driver can see groups assigned to them
create policy "ride_groups: assigned driver can read"
  on public.ride_groups for select
  using (auth.uid() = driver_id);

-- Groups are created and managed server-side only
create policy "ride_groups: no client insert"
  on public.ride_groups for insert
  with check (false);

create policy "ride_groups: no client update"
  on public.ride_groups for update
  using (false);

create policy "ride_groups: no client delete"
  on public.ride_groups for delete
  using (false);

-- ──── 4.5 group_members ────────────────────────────────────────────────

-- Rider can see their own member row
create policy "group_members: rider reads own"
  on public.group_members for select
  using (
    exists (
      select 1 from public.ride_requests rr
      where rr.id = group_members.request_id
        and rr.rider_id = auth.uid()
    )
  );

-- Driver sees all members of their assigned groups
create policy "group_members: driver reads assigned group"
  on public.group_members for select
  using (
    exists (
      select 1 from public.ride_groups rg
      where rg.id = group_members.group_id
        and rg.driver_id = auth.uid()
    )
  );

create policy "group_members: no client insert/update/delete"
  on public.group_members for all
  using (false);

-- ──── 4.6 payments ─────────────────────────────────────────────────────

-- Rider can see payments for their own member rows
create policy "payments: rider reads own"
  on public.payments for select
  using (
    exists (
      select 1
      from public.group_members gm
      join public.ride_requests rr on rr.id = gm.request_id
      where gm.id = payments.member_id
        and rr.rider_id = auth.uid()
    )
  );

-- Driver can see payments for members of their groups
create policy "payments: driver reads for assigned group"
  on public.payments for select
  using (
    exists (
      select 1
      from public.group_members gm
      join public.ride_groups rg on rg.id = gm.group_id
      where gm.id = payments.member_id
        and rg.driver_id = auth.uid()
    )
  );

create policy "payments: no client insert/update/delete"
  on public.payments for all
  using (false);

-- ──── 4.7 ratings ──────────────────────────────────────────────────────

-- Anyone involved in a group can read ratings for that group
create policy "ratings: member or driver can read"
  on public.ratings for select
  using (
    auth.uid() = rater_id
    or auth.uid() = ratee_id
  );

-- A user can submit a rating only as themselves
create policy "ratings: insert own"
  on public.ratings for insert
  with check (auth.uid() = rater_id);

-- No editing or deleting ratings
create policy "ratings: no update"
  on public.ratings for update
  using (false);

create policy "ratings: no delete"
  on public.ratings for delete
  using (false);

-- ──── 4.8 incidents ────────────────────────────────────────────────────

-- Reporter can read and insert their own incidents
create policy "incidents: reporter reads own"
  on public.incidents for select
  using (auth.uid() = reporter_id);

create policy "incidents: reporter inserts own"
  on public.incidents for insert
  with check (auth.uid() = reporter_id);

create policy "incidents: no update/delete by client"
  on public.incidents for update
  using (false);

create policy "incidents: no delete by client"
  on public.incidents for delete
  using (false);

-- ──── 4.9 pricing_config ───────────────────────────────────────────────

-- Every authenticated user can read pricing (needed to show fare estimates)
create policy "pricing_config: authenticated users can read"
  on public.pricing_config for select
  using (auth.role() = 'authenticated');

-- Only service_role (backend/Edge Functions) can modify pricing
create policy "pricing_config: no client write"
  on public.pricing_config for all
  using (false);


-- -----------------------------------------------------------------------
-- 5. Seed: default pricing configuration
-- -----------------------------------------------------------------------
insert into public.pricing_config (
  id,
  base_fare_bdt,
  per_km_rate_bdt,
  sharing_factor,
  platform_fee_pct,
  max_pickup_radius_m,
  max_dropoff_radius_m,
  max_detour_minutes,
  expire_before_min,
  small_group_fare_cap
) values (
  1,
  30.00,    -- ৳30 base fare
  18.00,    -- ৳18 per km
  0.700,    -- shared fare = 70% of solo route fare / group_size
  0.100,    -- 10% platform fee
  1500,     -- pickup within 1.5 km
  2000,     -- drop-off within 2 km
  10,       -- max detour 10 minutes
  15,       -- expire request 15 min before departure
  0.600     -- small-group price cap = 60% of solo fare
)
on conflict (id) do nothing;
