# ShareGari — Progress Log

---

## ✅ Step 1 — Project Skeleton (DONE)

**Date:** 2026-10-20

### What was done
- Feature-first folder structure, AppTheme.dark (Outfit font, teal-green primary), GoRouter, ProviderScope in main.dart
- `env.json` (gitignored) + `env.example.json`; all keys via `AppEnv` / `String.fromEnvironment`
- `flutter pub get` — clean; `flutter analyze lib` — No issues

---

## ✅ Step 2 — Database (DONE)

**Date:** 2026-10-20

### What was done
- `supabase/migrations/001_initial_schema.sql` — 9 tables, 7 enums, PostGIS, RLS, seed data

---

## ✅ Step 3 — Authentication (DONE)

**Date:** 2026-10-21

### What was done
- `supabase/migrations/002_auth_trigger.sql` — SECURITY DEFINER trigger auto-creates `public.users`
- Email auth (login + register screens), auth-guarded GoRouter, sign-out wired
- `flutter analyze lib` — No issues

### Before running
1. Run `002_auth_trigger.sql` in Supabase SQL editor
2. Supabase → **Authentication → Settings** → disable "Confirm email"

---

## ✅ Step 4 — Map and Location Picking (DONE)

**Date:** 2026-10-21

### What was done
- `flutter_map` 7.0.2 + `latlong2` + `http` added
- Abstract `GeocodingService` with Barikoi (primary) + Nominatim (fallback)
- `MapPicker` widget + `showLocationSearchSheet` bottom sheet
- `flutter analyze lib` — No issues

---

## ✅ Step 5 — Ride Request to Supabase + My Rides List (DONE)

**Date:** 2026-10-21

### What was done
- `RideRequest` model + `RideRequestStatus` enum; PostGIS WKT serialisation
- `RideRequestRepository`: insert, cancel, fetchMyRides, watchMyRides (Realtime)
- `myRidesProvider` — StreamProvider wired to Supabase Realtime
- `RideRequestScreen._submit()` → Supabase INSERT → navigate to `/my-rides`
- `MyRidesScreen` — live list, filter chips, ride cards, cancel, pull-to-refresh
- `flutter analyze lib` — No issues

---

## ✅ Step 6 — Fare Calculation + Unit Tests (DONE)

**Date:** 2026-10-21

### What was done

#### SQL migration
- `supabase/migrations/003_pricing_v2.sql`
  - Adds `per_min_rate_bdt NUMERIC(8,2) DEFAULT 2.00` to `pricing_config`
  - Adds `min_fare_bdt NUMERIC(8,2) DEFAULT 50.00` to `pricing_config`
  - Updates the singleton seed row with these values

#### New Dart files
| File | Purpose |
|------|---------|
| `lib/core/pricing/pricing_config.dart` | `PricingConfig` model; `PricingConfig.fallback` compile-time constant |
| `lib/core/pricing/pricing_config_repository.dart` | `PricingConfigNotifier` (AsyncNotifier) fetches singleton from Supabase; `pricingConfigSyncProvider` gives a non-nullable config immediately |
| `lib/core/pricing/fare_calculator.dart` | **Pure** `FareCalculator` — no Flutter/HTTP deps; unit-testable |
| `lib/core/pricing/fare_calculator_provider.dart` | Riverpod `Provider<FareCalculator>` wired to `pricingConfigSyncProvider` |
| `lib/core/routing/routing_service.dart` | Abstract `RoutingService` + `OrsRouteResult` (distance_m, duration_s, km/min helpers) |
| `lib/core/routing/ors_routing_service.dart` | ORS `POST /v2/directions/driving-car/json` impl; `_NoopRoutingService` fallback; `routingServiceProvider` selects by key presence |
| `test/fare_calculator_test.dart` | **15 unit tests** — all passing ✅ |

#### Updated files
| File | Change |
|------|--------|
| `lib/features/ride_request/ride_request_screen.dart` | Calls `_refreshRoute()` on every pin change; shows `_FareBanner` (live range) or `_RouteLoadingBanner`; passes `estimatedSoloFare` + `estimatedShareFare` into `RideRequest` before INSERT |
| `lib/features/ride_request/data/ride_request_model.dart` | `toInsertJson()` now includes `estimated_solo_fare`/`estimated_share_fare` when non-null |

- `flutter analyze lib` — **No issues found**
- `flutter test test/fare_calculator_test.dart` — **15/15 passed**

### Fare formula (from PRD §7.3)
```
car_fare  = max(min_fare_bdt, base_fare_bdt + per_km_rate × km + per_min_rate × min)
rider_fare(n) = roundUp5(car_fare / n × (1 + platform_fee_pct))
```

### Pre-match estimate shown to rider
Uses the rider's own trip as route proxy:
- `low`  = `rider_fare(n=4)` → best-case (4-person group)
- `high` = `rider_fare(n=2)` → worst-case (2-person group)
- Displayed as: `৳70 – ৳140`

### Pricing values (all in Supabase `pricing_config` — never hardcoded)
| Column | Default | Meaning |
|--------|---------|---------|
| `base_fare_bdt` | ৳30 | Fixed base per ride |
| `per_km_rate_bdt` | ৳18/km | Distance component |
| `per_min_rate_bdt` | ৳2/min | Duration component *(new)* |
| `min_fare_bdt` | ৳50 | Minimum car fare *(new)* |
| `platform_fee_pct` | 10% | Added to each rider's fare |

### Architecture
```
RoutingService (abstract)
  └── OrsRoutingService   ← POST /v2/directions/driving-car/json
         ↓ OrsRouteResult (distance_m, duration_s)
FareCalculator (pure Dart, no deps)
  ← PricingConfig (from Supabase pricing_config singleton)
         ↓ FareRange / riderFare(n)
RideRequestScreen
  → estimated_solo_fare (n=1) stored on ride_requests row
  → estimated_share_fare (n=4) stored on ride_requests row
```

### Known issues / TODOs
- When a group is formed (Step 7), the matching engine must re-calculate `car_fare` over the **full shared route** (all stops ordered) and save the locked fare on each `group_members.fare` column. The formula is identical; only the route input changes.
- ORS free tier: 2,000 req/day. The screen only calls ORS once per unique (pickup, dropoff) pair — not on every keystroke.
- `per_min_rate_bdt` and `min_fare_bdt` were added with `DEFAULT` so existing DB rows that haven't run `003_pricing_v2.sql` yet degrade gracefully to the `PricingConfig.fallback` constants.

### Bug fixes applied after Step 6 (same session)

#### Fix 1 — `FormatException: Invalid double 0101000020E6100000…` on My Rides

**Root cause:** PostgREST returns `geography(Point)` columns as raw hex EWKB, not WKT. `fromJson` tried to cast it to a `num` → `FormatException`.

**Fix:**
- `supabase/migrations/004_geo_latlong_columns.sql` — adds four `GENERATED ALWAYS AS STORED` columns:
  `pickup_lat`, `pickup_lng`, `drop_lat`, `drop_lng` using `ST_Y`/`ST_X`.
- `lib/features/ride_request/data/ride_request_model.dart` — `fromJson` reads the plain `double` generated columns; `_parseGeo` removed; `toInsertJson` still writes EWKT to `pickup_geo`/`drop_geo`.
- `lib/features/ride_request/data/ride_request_repository.dart` — all SELECT calls use `_cols` constant that explicitly names the generated columns and **excludes** `pickup_geo`/`drop_geo`. The `.stream()` call returns all columns but `fromJson` only reads the keys it needs, ignoring the hex EWKB ones.

#### Fix 2 — Supabase Realtime publication

**Root cause:** Supabase Realtime only pushes changes for tables in the `supabase_realtime` publication. The user ran `alter publication supabase_realtime add table public.ride_requests` by hand.

**Fix:**
- `supabase/migrations/005_realtime_publication.sql` — idempotent migration (guards with `pg_publication_tables` check) that adds `ride_requests`, `ride_groups`, and `group_members` to the publication.
- RLS SELECT policies for all three tables already exist from `001_initial_schema.sql`; Realtime respects RLS so no additional policies are needed.

---

## ⏭️ Step 7 — Matching Engine (NEXT)

**Prompt to use:**
> "Implement matching as a Supabase SQL function (PostGIS) or Edge Function following the PRD compatibility rules: overlapping time windows, pickup within 1.5 km, drop-off within 2 km, groups of 2-4. Create ride_groups and group_members. Write tests with sample data. Add a script that inserts 10 fake requests so I can test it."

**What to do manually before Step 7:**
1. Run `supabase db push` to apply migrations 003, 004, 005.
2. Verify My Rides no longer throws `FormatException` — existing rows now have `pickup_lat`/`pickup_lng` populated.
3. Verify Realtime: open two browser tabs → submit a ride in one → confirm the list in the other updates without refresh.
4. Commit: `git add . && git commit -m "Step 6 complete + geo/realtime fixes"`

---

## Upcoming steps (reference)

| Step | Topic | Status |
|------|-------|--------|
| 1 | Project skeleton, Riverpod, GoRouter, theme, placeholder screens | Done |
| 2 | Supabase SQL migration + PostGIS + RLS | Done |
| 3 | Supabase auth (email dev, phone OTP later) | Done |
| 4 | flutter_map + OpenStreetMap + Barikoi geocoding | Done |
| 5 | Ride request to Supabase, My Rides list | Done |
| 6 | Fare calculation (ORS distance), unit tests + geo/realtime fixes | Done |
| 7 | Matching engine (PostGIS SQL function) | **Next** |
| 8 | Realtime group status screen | - |
| 9 | Driver mode screens | - |
| 10 | Live tracking | - |
| 11 | Push notifications (FCM) | - |
| 12 | Payments (cash + bKash/Nagad) | - |
| 13 | Ratings, SOS, admin panel | - |
| 14 | Driver auto-assign, Bangla i18n, beta | - |


