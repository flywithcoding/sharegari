-- ── Step 6: Add per-minute rate and minimum fare to pricing_config ──────────
--
-- The fare formula is:
--   car_fare = max(min_fare, base_fare + per_km × route_km + per_min × route_min)
--   rider_fare = roundUp5(car_fare / group_size)
--
-- The existing sharing_factor column is kept for backward compatibility and
-- is used by the matching engine (Step 7) to cap small-group fares.

alter table public.pricing_config
  add column if not exists per_min_rate_bdt  numeric(8,2) not null default 2.00,
  add column if not exists min_fare_bdt      numeric(8,2) not null default 50.00;

comment on column public.pricing_config.per_min_rate_bdt is
  'Taka charged per minute of route duration.';
comment on column public.pricing_config.min_fare_bdt is
  'Minimum car fare regardless of distance/time.';

-- Update the singleton seed row with sensible defaults.
update public.pricing_config
set
  per_min_rate_bdt = 2.00,
  min_fare_bdt     = 50.00,
  updated_at       = now()
where id = 1;
