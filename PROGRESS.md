# ShareGari — Progress Log

---

## ✅ Step 1 — Project Skeleton (DONE)

**Date:** 2026-10-20

### What was done
- Created feature-first folder structure:
  - `lib/features/auth/` — LoginScreen (placeholder)
  - `lib/features/home/` — HomeScreen with bottom nav + FAB
  - `lib/features/ride_request/` — RideRequestScreen (pickup, drop-off, time picker, flexibility slider, map placeholder)
  - `lib/features/my_rides/` — MyRidesScreen with status filter chips
  - `lib/features/matching/` — stub (Step 7)
  - `lib/features/driver/` — stub (Step 9)
  - `lib/features/payments/` — stub (Step 12)
- Added `lib/core/env.dart` (AppEnv) — reads all API keys via String.fromEnvironment; run the app with `flutter run --dart-define-from-file=env.json`
- Added `lib/core/theme/app_theme.dart` (AppTheme.dark) — dark ShareGari brand theme using Outfit font, teal-green primary (#00C6A7), deep-orange accent
- Added `lib/core/router/app_router.dart` — GoRouter with named routes: /login, /, /ride-request, /my-rides
- Rewrote `lib/main.dart` — ProviderScope (Riverpod) + MaterialApp.router + AppTheme.dark
- Updated `pubspec.yaml` — added: flutter_riverpod, riverpod_annotation, go_router, supabase_flutter, google_fonts, build_runner, riverpod_generator, custom_lint, riverpod_lint
- Created `env.json` with required key names; created `env.example.json`; added `env.json` to `.gitignore`
- `flutter pub get` — OK (113 deps resolved)
- `flutter analyze lib` — No issues found

### How to run

```sh
flutter run --dart-define-from-file=env.json
```

---

## ✅ Step 2 — Database (DONE)

**Date:** 2026-10-20

### What was done
- Created `supabase/migrations/001_initial_schema.sql`

#### Extensions enabled
- `uuid-ossp` — for `uuid_generate_v4()` primary keys
- `postgis` — for geo columns and spatial queries

#### Custom enums
`user_role`, `driver_status`, `request_status`, `group_status`, `member_status`, `payment_method`, `payment_status`

#### Tables (9 total)
| Table | Key columns |
|-------|-------------|
| `users` | id (→ auth.users), name, phone, role, fcm_token, rating |
| `drivers` | user_id, nid, license_no, plate, seat_capacity, status, is_online, `location geography(Point,4326)` |
| `ride_requests` | id, rider_id, `pickup_geo`, `drop_geo` (both `geography(Point,4326)`), pickup_address, drop_address, depart_at, window_min, estimated fares, status |
| `ride_groups` | id, driver_id, status, route_json (jsonb), fare_total, platform_fee, depart_at |
| `group_members` | id, group_id, request_id, fare, pickup_order, dropoff_order, status |
| `payments` | id, member_id, method, amount, status, provider_ref, paid_at |
| `ratings` | id, group_id, rater_id, ratee_id, score, comment |
| `incidents` | id, group_id, reporter_id, description, resolved |
| `pricing_config` | singleton row (id=1); base_fare_bdt=30, per_km_rate=18, sharing_factor=0.7, platform_fee=10%, radii, detour limits |

#### Indexes (11 total)
- 3× PostGIS `GIST` indexes: `pickup_geo`, `drop_geo`, `drivers.location`
- 8× btree indexes for status/depart_at lookups and foreign key joins

#### RLS policies
Every table has RLS enabled. Key rules:
- **users**: read/update own row only; insert/delete blocked client-side (server trigger creates profile)
- **drivers**: read/update own profile only
- **ride_requests**: rider reads/inserts/updates (pending only) own rows
- **ride_groups**: rider sees groups they're a member of; driver sees assigned groups; no client writes
- **group_members**: rider sees own; driver sees their group's members; no client writes
- **payments**: rider/driver see relevant payments; no client writes
- **ratings**: rater/ratee can read; user inserts as themselves only; no edit/delete
- **incidents**: reporter reads/inserts own; no client edit/delete
- **pricing_config**: all authenticated users can read; no client writes

#### Seed data
- `pricing_config` singleton row with MVP defaults

### How to apply
1. Open your Supabase project → **SQL Editor**
2. Paste the entire content of `supabase/migrations/001_initial_schema.sql`
3. Click **Run**

Or if you have the Supabase CLI set up:
```sh
supabase db push
```

### Known issues / TODOs
- `users: insert via service role only` policy has `with check (false)`. Step 3 will add a Postgres trigger on `auth.users` insert to auto-create the `public.users` row using the service role — this avoids any client insert.
- The `drivers.location` column needs a realtime publication added in Step 10 for live tracking.
- `ride_groups.route_json` format (GeoJSON vs ordered stop list) will be finalised in Step 7 when the matching engine is built.

---

## ⏭️ Step 3 — Authentication (NEXT)

**Prompt to use:**
> "Add Supabase auth to the Flutter app. Use email login for development (phone OTP needs a paid SMS provider; we will switch later). Add a user profile row on signup and a role (rider/driver)."

**What to do manually before Step 3:**
1. Run `supabase/migrations/001_initial_schema.sql` in the Supabase SQL editor.
2. Verify all 9 tables appear in the Table Editor and that PostGIS is listed under Extensions.
3. Fill in remaining `env.json` keys (ORS, Barikoi, MapTiler) if not done yet.
4. Commit: `git add . && git commit -m "Step 2 done"`

---

## Upcoming steps (reference)

| Step | Topic | Status |
|------|-------|--------|
| 1 | Project skeleton, Riverpod, GoRouter, theme, placeholder screens | Done |
| 2 | Supabase SQL migration + PostGIS + RLS | Done |
| 3 | Supabase auth (email dev, phone OTP later) | Next |
| 4 | flutter_map + OpenStreetMap + Barikoi geocoding | - |
| 5 | Ride request to Supabase, My Rides list | - |
| 6 | Fare calculation (ORS distance), unit tests | - |
| 7 | Matching engine (PostGIS SQL function) | - |
| 8 | Realtime group status screen | - |
| 9 | Driver mode screens | - |
| 10 | Live tracking | - |
| 11 | Push notifications (FCM) | - |
| 12 | Payments (cash + bKash/Nagad) | - |
| 13 | Ratings, SOS, admin panel | - |
| 14 | Driver auto-assign, Bangla i18n, beta | - |
