# ShareGari — Progress Log

---

## ✅ Step 1 — Project Skeleton (DONE)

**Date:** 2026-10-20

### What was done
- Feature-first folder structure, AppTheme.dark (Outfit font, teal-green primary), GoRouter, ProviderScope in main.dart
- `env.json` (gitignored) + `env.example.json`; all keys via `AppEnv` / `String.fromEnvironment`
- `flutter pub get` — 113 deps; `flutter analyze lib` — No issues

### How to run
```sh
flutter run --dart-define-from-file=env.json
```

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
2. Supabase dashboard → **Authentication → Settings** → disable "Confirm email"

---

## ✅ Step 4 — Map and Location Picking (DONE)

**Date:** 2026-10-21

### What was done
- `flutter_map` 7.0.2 + `latlong2` + `http` added
- Abstract `GeocodingService` with Barikoi (primary) + Nominatim (fallback) implementations
- `MapPicker` widget: tap-to-pin, mode toggle, auto reverse-geocode, dotted polyline
- `showLocationSearchSheet`: debounced bottom-sheet search
- `flutter analyze lib` — No issues

---

## ✅ Step 5 — Ride Request to Supabase + My Rides List (DONE)

**Date:** 2026-10-21

### What was done

#### New package
- `intl: ^0.20.1` — for `DateFormat` in the ride card

#### New files
| File | Purpose |
|------|---------|
| `lib/features/ride_request/data/ride_request_model.dart` | `RideRequest` model + `RideRequestStatus` enum; PostGIS WKT serialisation |
| `lib/features/ride_request/data/ride_request_repository.dart` | `insert()`, `cancel()`, `fetchMyRides()`, `watchMyRides()` stream |
| `lib/features/ride_request/providers/ride_request_providers.dart` | `myRidesProvider` — Riverpod `StreamProvider` wired to Supabase Realtime |

#### Updated files
| File | Change |
|------|--------|
| `lib/features/ride_request/ride_request_screen.dart` | `_submit()` calls `repository.insert()`; loading spinner + error banner; navigates to `/my-rides` on success |
| `lib/features/my_rides/my_rides_screen.dart` | Full real-time list from Supabase; filter chips; ride cards with status badge, route, fare; cancel button; pull-to-refresh; empty/error states |

- `flutter analyze lib` — **No issues found**

### Data flow
```
RideRequestScreen._submit()
  → RideRequest.toInsertJson()         (WKT geo, UTC timestamps)
  → RideRequestRepository.insert()      (Supabase INSERT → SELECT)
  → navigate to /my-rides

MyRidesScreen
  → myRidesProvider (StreamProvider)
  → RideRequestRepository.watchMyRides()
  → Supabase Realtime (.stream())
  → rebuilds on every INSERT/UPDATE/DELETE
```

### PostGIS geography handling
- **INSERT**: `SRID=4326;POINT(lng lat)` WKT string → PostGIS parses on server
- **SELECT**: Supabase returns `POINT(lng lat)` WKT → `_parseGeo()` splits to `LatLng`

### Known issues / TODOs
- `RideRequestStatus.inProgress` name maps to `in_progress` DB string — handled in `_dbStatus()` switch. Dart enum names can't contain underscores.
- `fetchMyRides` is not used by the screen (it uses the realtime stream) but is available for non-realtime contexts (e.g., tests, export).
- `estimated_solo_fare` / `estimated_share_fare` columns remain null until Step 6 (ORS distance + fare calculator).
- The `intl` package version is pinned to `^0.20.1` (already a transitive dep via flutter_map); no additional download was needed.

---

## ⏭️ Step 6 — Fare Calculation + Unit Tests (NEXT)

**Prompt to use:**
> "Use OpenRouteService to get route distance and duration. Implement the fare calculator from the PRD (solo fare, shared fare, platform fee). Put the pricing numbers in a config table. Write unit tests. Show estimated solo vs shared price on the request screen."

**What to do manually before Step 6:**
1. Verify the full flow end-to-end: register → Request Ride → pin locations → submit → see request in My Rides
2. Check Supabase Table Editor: confirm the row appears in `ride_requests` with correct `pickup_geo`, `drop_geo`, `depart_at`
3. Commit: `git add . && git commit -m "Step 5 done"`

---

## Upcoming steps (reference)

| Step | Topic | Status |
|------|-------|--------|
| 1 | Project skeleton, Riverpod, GoRouter, theme, placeholder screens | Done |
| 2 | Supabase SQL migration + PostGIS + RLS | Done |
| 3 | Supabase auth (email dev, phone OTP later) | Done |
| 4 | flutter_map + OpenStreetMap + Barikoi geocoding | Done |
| 5 | Ride request to Supabase, My Rides list | Done |
| 6 | Fare calculation (ORS distance), unit tests | Next |
| 7 | Matching engine (PostGIS SQL function) | - |
| 8 | Realtime group status screen | - |
| 9 | Driver mode screens | - |
| 10 | Live tracking | - |
| 11 | Push notifications (FCM) | - |
| 12 | Payments (cash + bKash/Nagad) | - |
| 13 | Ratings, SOS, admin panel | - |
| 14 | Driver auto-assign, Bangla i18n, beta | - |
