-- ── Step 6b: Expose lat/lng as plain numeric generated columns ─────────────
--
-- Problem: PostgREST / Supabase returns geography(Point) columns as hex EWKB,
-- e.g. "0101000020E6100000...", which Dart cannot parse as a coordinate.
--
-- Fix: Add GENERATED ALWAYS AS computed columns that extract the coordinates
-- using ST_Y (latitude) and ST_X (longitude). PostgREST returns these as
-- plain numeric values that Dart can read directly.
--
-- INSERT behaviour is unchanged: callers still write to pickup_geo / drop_geo
-- using EWKT ("SRID=4326;POINT(lng lat)") and the generated columns update
-- automatically.

alter table public.ride_requests
  add column if not exists pickup_lat double precision
    generated always as (st_y(pickup_geo::geometry)) stored,

  add column if not exists pickup_lng double precision
    generated always as (st_x(pickup_geo::geometry)) stored,

  add column if not exists drop_lat double precision
    generated always as (st_y(drop_geo::geometry)) stored,

  add column if not exists drop_lng double precision
    generated always as (st_x(drop_geo::geometry)) stored;

comment on column public.ride_requests.pickup_lat is
  'Latitude of the pickup point. Generated from pickup_geo. Read-only.';
comment on column public.ride_requests.pickup_lng is
  'Longitude of the pickup point. Generated from pickup_geo. Read-only.';
comment on column public.ride_requests.drop_lat is
  'Latitude of the drop-off point. Generated from drop_geo. Read-only.';
comment on column public.ride_requests.drop_lng is
  'Longitude of the drop-off point. Generated from drop_geo. Read-only.';
