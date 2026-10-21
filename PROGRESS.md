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
- `supabase/migrations/001_initial_schema.sql`
  - Extensions: `uuid-ossp`, `postgis`
  - 7 custom enums, 9 tables (with `geography(Point,4326)` geo columns), 11 indexes (3× GIST), RLS on all tables
  - Seeded `pricing_config` singleton (৳30 base, ৳18/km, 70% sharing factor, 10% fee)

### How to apply
1. Supabase dashboard → **SQL Editor** → paste `001_initial_schema.sql` → **Run**
2. Verify 9 tables + PostGIS extension visible

---

## ✅ Step 3 — Authentication (DONE)

**Date:** 2026-10-21

### What was done

#### SQL
- `supabase/migrations/002_auth_trigger.sql`
  - `handle_new_user()` SECURITY DEFINER trigger — fires on every `auth.users` INSERT
  - Inserts a `public.users` row from signup metadata (name, phone, role)

#### Flutter — new / updated files
| File | Change |
|------|--------|
| `lib/core/supabase/supabase_client_provider.dart` | `Provider<SupabaseClient>` |
| `lib/features/auth/data/auth_repository.dart` | sign up / in / out; `AuthResult` value object |
| `lib/features/auth/providers/auth_providers.dart` | `authStateProvider` (stream) + `currentUserProvider` |
| `lib/features/auth/login_screen.dart` | Real email+password form |
| `lib/features/auth/register_screen.dart` | Name, email, phone, password, role picker |
| `lib/core/router/app_router.dart` | Auth-guarded router + `_AuthChangeNotifier` |
| `lib/main.dart` | `Supabase.initialize` live; `ConsumerWidget` |
| `lib/features/home/home_screen.dart` | Sign-out button wired to `AuthRepository` |

- `flutter analyze lib` — **No issues found**

### Before running Step 3
1. Run `supabase/migrations/002_auth_trigger.sql` in Supabase SQL editor
2. Supabase dashboard → **Authentication → Settings** → disable "Confirm email" (dev only)
3. `flutter run --dart-define-from-file=env.json`

---

## ✅ Step 4 — Map and Location Picking (DONE)

**Date:** 2026-10-21

### What was done

#### New packages added
| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_map` | 7.0.2 | OSM map tiles + tap-to-pin |
| `latlong2` | 0.9.1 | `LatLng` type |
| `http` | 1.2.2 | Barikoi / Nominatim REST calls |

#### New files
| File | Purpose |
|------|---------|
| `lib/core/location/location_model.dart` | `LocationResult` value object (LatLng + address + name) |
| `lib/core/location/geocoding_service.dart` | Abstract `GeocodingService` interface (search + reverseGeocode) |
| `lib/core/location/barikoi_geocoding_service.dart` | Barikoi implementation (BD-focused, free tier) |
| `lib/core/location/nominatim_geocoding_service.dart` | Nominatim/OSM fallback (no key needed; respects rate limit) |
| `lib/core/location/geocoding_provider.dart` | Riverpod `Provider<GeocodingService>` — uses Barikoi if key present, Nominatim otherwise |
| `lib/features/ride_request/widgets/map_picker.dart` | `MapPicker` ConsumerStatefulWidget — flutter_map with tap-to-pin, mode toggle, auto reverse-geocode |
| `lib/features/ride_request/widgets/location_search_sheet.dart` | `showLocationSearchSheet()` — debounced bottom sheet search returning `LocationResult` |

#### Updated file
- `lib/features/ride_request/ride_request_screen.dart` — replaced `_MapPlaceholder` with live `MapPicker` + `_LocationField` tap-to-search fields, `_FlexChips` (±10/15/20 min), "Find Shared Ride" button disabled until both pins are set

#### Architecture: geocoding is behind an interface
```
GeocodingService (abstract)
  ├── BarikoiGeocodingService  ← used when BARIKOI_API_KEY present
  └── NominatimGeocodingService ← fallback, no key needed
```
Swapping provider requires changing one line in `geocoding_provider.dart`.

#### Tile provider selection (no hardcoded keys)
```
AppEnv.mapTilerApiKey present? → MapTiler Streets free tier (100k/month)
                          else → tile.openstreetmap.org (no key)
```

- `flutter analyze lib` — **No issues found**

### How location picking works
1. Screen opens: map centred on Dhaka (23.8103, 90.4125)
2. Tap map → pins pickup (green) or drop-off (orange) depending on mode toggle
3. After tap: auto reverse-geocode fills the address field
4. OR: tap a location field → `showLocationSearchSheet` opens → type ≥2 chars → debounced `GeocodingService.search()` → tap result → field and pin both update
5. Dotted polyline drawn between pickup and drop-off when both are set
6. "Find Shared Ride" button enabled only when both locations are set

### Before running Step 4
1. Fill `BARIKOI_API_KEY` and `MAPTILER_API_KEY` in `env.json` (already done)
2. `flutter run --dart-define-from-file=env.json`
3. Navigate: Home → "Request Ride" FAB

### Known issues / TODOs
- Nominatim rate limit: 1 req/s. The debounce (400ms) + search-only-on-submit design prevents bursting, but add a stricter queue if heavy testing is done.
- MapController is disposed but `FlutterMap` does not need an externally provided controller; it was kept for future programmatic pan/zoom (Step 10 tracking).
- `AppEnv.assertAll()` still asserts ORS/Barikoi/MapTiler keys; those will naturally be present for Steps 4–6.

---

## ⏭️ Step 5 — Ride Request to Supabase + My Rides List (NEXT)

**Prompt to use:**
> "Let the rider choose a departure time and time flexibility, then save a ride_request to Supabase. Show 'My Rides' with status. No matching yet."

**What to do manually before Step 5:**
1. Verify the map and search work end-to-end on a device/emulator
2. Commit: `git add . && git commit -m "Step 4 done"`

---

## Upcoming steps (reference)

| Step | Topic | Status |
|------|-------|--------|
| 1 | Project skeleton, Riverpod, GoRouter, theme, placeholder screens | Done |
| 2 | Supabase SQL migration + PostGIS + RLS | Done |
| 3 | Supabase auth (email dev, phone OTP later) | Done |
| 4 | flutter_map + OpenStreetMap + Barikoi geocoding | Done |
| 5 | Ride request to Supabase, My Rides list | Next |
| 6 | Fare calculation (ORS distance), unit tests | - |
| 7 | Matching engine (PostGIS SQL function) | - |
| 8 | Realtime group status screen | - |
| 9 | Driver mode screens | - |
| 10 | Live tracking | - |
| 11 | Push notifications (FCM) | - |
| 12 | Payments (cash + bKash/Nagad) | - |
| 13 | Ratings, SOS, admin panel | - |
| 14 | Driver auto-assign, Bangla i18n, beta | - |
