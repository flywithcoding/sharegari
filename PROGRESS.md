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

## ✅ Step 7 — Matching Engine (DONE)

**Date:** 2026-10-21

### What was done

#### SQL migrations for Step 7

> **Note — enum split:** PostgreSQL does not allow a newly added enum value to be used
> in the same transaction. Supabase runs each migration file in one transaction, so the
> enum additions **must** be in a separate file from the schema/function that uses them.

| File | Change |
|------|--------|
| `supabase/migrations/006_matching_engine.sql` | **Only** `ALTER TYPE ... ADD VALUE` for `'searching'` and `'pending_driver'`. Commits these values before 007 runs. |
| `supabase/migrations/007_matching_engine_schema.sql` | Default status change, `'pending'` migration, `matching_window_min` config column, and the full `run_matching()` function. |

| Schema change | Detail |
|---------------|--------|
| Enum: `request_status` | Added `'searching'` (new requests default to this; engine promotes to `'matched'`) |
| Enum: `group_status` | Added `'pending_driver'` (newly formed groups start here; Step 8 moves to `'confirmed'`) |
| `ride_requests.status` default | Changed from `'pending'` → `'searching'` |
| Existing `'pending'` rows | Migrated to `'searching'` |
| `pricing_config.matching_window_min` | Added (`int`, default 60) — look-ahead window in minutes |
| `run_matching()` | Full SECURITY DEFINER PL/pgSQL function (see below) |

#### `run_matching()` function

- **Expiry first**: marks `searching` rows as `expired` if departure ≤ `expire_before_min` minutes away (default 15).
- **Eligible window**: considers `searching` requests departing within `matching_window_min` minutes (default 60).
- **Concurrency**: outer and inner loops both use `FOR UPDATE SKIP LOCKED` — safe for parallel calls.
- **Compatibility** (all three must hold, using PostGIS geography columns):
  - Time windows overlap
  - Pickup distance ≤ `max_pickup_radius_m` (default 1500 m)
  - Drop-off distance ≤ `max_dropoff_radius_m` (default 2000 m)
- **Greedy NN ordering**: candidates added nearest-pickup-first; `pickup_order` = batch position.
- **Group size**: 2–4 riders (anchor + up to 3 candidates). Prefers 4 > 3 > 2 naturally via the `LIMIT 3` candidate query.
- **Fare**: `car_fare = max(min_fare, base + per_km × km + per_min × min)` where `km = straight_line × 1.30`. `rider_fare = roundUp5(car_fare / n × (1 + platform_fee_pct))`.
- **Writes**: `ride_groups` (status `pending_driver`), `group_members` (with `pickup_order`/`dropoff_order`, locked `fare`), and `ride_requests.status = 'matched'`.
- **Returns**: JSONB `{groups_formed, riders_matched, riders_expired, ran_at}`.

#### pg_cron
Supabase **Free/Starter** plans do **not** have `pg_cron`. Call the function manually:
```sql
SELECT run_matching();
```
To check if your project has pg_cron:
```sql
SELECT * FROM pg_extension WHERE extname = 'pg_cron';
```
If it's available, uncomment the `cron.schedule` block at the bottom of `007_matching_engine_schema.sql` and push again.

#### Config table (all limits in `pricing_config` — never hardcoded)

| Column | Default | Meaning |
|--------|---------|---------|
| `max_pickup_radius_m` | 1500 m | Max pickup distance for compatibility |
| `max_dropoff_radius_m` | 2000 m | Max drop-off distance for compatibility |
| `expire_before_min` | 15 min | Requests expiry threshold |
| `matching_window_min` | 60 min | Look-ahead window *(added by this migration)* |

#### Test files

| File | Purpose |
|------|---------|
| `supabase/seed_test_requests.sql` | 10 fake requests: Group A (4 Uttara→Motijheel), Group B (2 Mirpur→Gulshan), Group C (2 Dhanmondi→Farmgate), 2 no-match cases (Chittagong + departure >60 min) |
| `supabase/verify_matching.sql` | Runs `run_matching()`, then shows: request status summary, groups formed, member fares, divisibility-by-5 check, no-match verification, pickup-proximity sanity query |

#### Flutter changes (minimal — no new screens)

| File | Change |
|------|--------|
| `lib/features/ride_request/data/ride_request_model.dart` | Added `searching` to `RideRequestStatus` enum, `fromString`, `label`, `isActive` |
| `lib/features/ride_request/ride_request_screen.dart` | `_submit()` now sets `status: RideRequestStatus.searching` |
| `lib/features/my_rides/my_rides_screen.dart` | Filter chip, `_dbStatus`, cancel guard, `_statusBorderColor`, `_StatusBadge` all handle `searching` |

- `flutter analyze lib` → **No issues**

### Known limitations / Step 10 TODOs
- **Route distance**: using `straight_line × 1.30` as a proxy. Replace with ORS `/v2/directions` call in Step 10 (or an Edge Function callable from within the DB function).
- **dropoff_order**: currently FIFO (same order as pickup). True greedy drop-off ordering (sort by distance from the last pickup) is a Phase 2 improvement.
- **pg_cron**: left as commented stub. Free/Starter plan users must call `SELECT run_matching();` manually or set up a cron-triggered Edge Function.

---

## ✅ Step 8 — Realtime Group Status Screen (DONE)

**Date:** 2026-10-21

### What was done

#### SQL migration: `supabase/migrations/010_rider_status_screen.sql`

| Change | Detail |
|--------|--------|
| Enum: `group_status` | Added `'driver_assigned'` (between `pending_driver` and `confirmed`) |
| View: `my_group_co_riders` | `security_invoker = true` — first-name-only co-rider data, RLS-scoped to current user's groups |
| Function: `cancel_ride_request(uuid)` | Smart cancel: free while searching; cascades to dissolve group if < 2 riders remain, requeues the rest to `'searching'` |

#### Flutter files created

| File | Purpose |
|------|---------|
| `lib/features/ride_status/data/ride_status_models.dart` | `GroupStatus` enum, `CoRider`, `DriverDetail`, `GroupDetail` models |
| `lib/features/ride_status/data/ride_status_repository.dart` | Queries + Realtime streams for request/group status; calls `cancel_ride_request` RPC |
| `lib/features/ride_status/providers/ride_status_providers.dart` | `requestStatusStreamProvider`, `groupDetailProvider`, `groupStatusStreamProvider` (all family) |
| `lib/features/ride_status/ride_status_screen.dart` | Full status screen — 4 state views (searching, group formed, expired, cancelled) |

#### Flutter files modified

| File | Change |
|------|--------|
| `lib/core/router/app_router.dart` | Added `/ride-status/:requestId` route with extra params |
| `lib/features/ride_request/ride_request_screen.dart` | Post-submit navigates to status screen (instead of My Rides) |
| `lib/features/my_rides/my_rides_screen.dart` | Ride cards are tappable → open status screen; added chevron indicator |

#### Test / helper files

| File | Purpose |
|------|---------|
| `supabase/test_status_flow.sql` | Commented SQL to manually advance a group through all statuses (pending_driver → driver_assigned → confirmed → in_progress → completed) |

#### Screen states

| Status | What the rider sees |
|--------|-------------------|
| `searching` / `pending` | Pulsing "Finding riders" animation, trip details, fare range, Cancel button |
| `matched` + group found | Group count, my locked fare, departure time, co-rider first names + pickup order, Cancel with fee warning |
| `driver_assigned` / `confirmed` | + driver first name, car model, plate, rating |
| `expired` | "No match found" + "Try a different time" + "Back to My Rides" buttons |
| `cancelled` | "Ride cancelled" + "Book a new ride" |

#### Cancel logic

- **While searching**: direct `cancel_ride_request()` call, no fee, no confirmation needed beyond dialog.
- **After group formed**: confirmation dialog with fee warning (no charging in MVP); SQL function dissolves group if < 2 riders remain and requeues survivors to `'searching'`.

#### Realtime

- `requestStatusStreamProvider` streams `ride_requests.status` live.
- `groupStatusStreamProvider` streams `ride_groups.status` live.
- Both auto-unsubscribe when the provider is disposed (screen closes).
- Group detail re-fetched (`ref.invalidate`) whenever the group status stream emits a changed value.

#### `flutter analyze lib` → **No issues**

---

## ✅ Bug fix — Android login stuck in loading state (DONE)

**Date:** 2026-10-21

### Root cause

`currentUserProvider` was a plain `Provider<User?>` that called `_client.auth.currentUser` synchronously. GoRouter's `redirect` read this value but it never updated reactively after sign-in. On Android, `signInWithPassword` succeeds asynchronously; the login screen called `context.go(AppRoutes.home)` manually, but the router's `redirect` still saw `isLoading = true` (the StreamProvider hadn't emitted yet) and overrode the navigation with `null`. Result: loading spinner forever.

### Fixes

| File | Change |
|------|--------|
| `lib/features/auth/providers/auth_providers.dart` | Added `authUserProvider` — a `StreamProvider<User?>` mapping `onAuthStateChange` to `User?`. This is reactive; the router re-evaluates redirect on every emission. Kept `currentUserProvider` as a derived `Provider<User?>` from it (backward compat for other screens). |
| `lib/core/router/app_router.dart` | Router's `refreshListenable` and `redirect` now use `authUserProvider` instead of `currentUserProvider`. The redirect fires correctly after sign-in on Android. |
| `lib/features/auth/login_screen.dart` | (1) Removed `context.go()` after success — router redirect handles navigation. (2) `_loading` cleared in both success and error branches. (3) 15-second timeout on `signInWithEmail`. (4) `debugPrint` logs auth outcome and unexpected errors. |

- `flutter analyze lib` → **No issues**

---

## ✅ Bug fix — Release APK stuck on splash (R8 minification) (DONE)

**Date:** 2026-10-21

### Root cause

R8 (the release minifier) was enabled by default for the release build type. It renamed / removed methods accessed via reflection inside `shared_preferences_android`, producing:

```
NoSuchMethodError: no non-static method
  SharedPreferencesApiRegistrar.getAll
```

This caused the app to crash at plugin registration time, before Flutter could render any UI — appearing as a frozen splash screen.

### Fix

| File | Change |
|------|--------|
| `android/app/build.gradle.kts` | Added `isMinifyEnabled = false` and `isShrinkResources = false` to the `release` build type. Also wired in `proguardFiles` for future use. |
| `android/app/proguard-rules.pro` | Created with keep rules for `io.flutter.plugins.**`, `io.flutter.embedding.**`, `shared_preferences`, Supabase/OkHttp, and general annotation attributes. Currently inactive (minification is off) but provides a safe starting point if minification is re-enabled later. |

### To rebuild the release APK after this fix
```powershell
flutter clean
flutter build apk --release
# or for app bundle:
flutter build appbundle --release
```

---

## ✅ Bug fix — Navigation: My Rides back button missing (DONE)

**Date:** 2026-10-21

### Root cause

Two problems compounded:

1. **`ride_request_screen.dart`** used `context.go(rideStatusPath)` after submitting a ride — this replaced the entire stack, so Status Screen had no history and `context.canPop()` returned false. When "Back" was pressed and the screen called `context.go(myRides)`, My Rides was placed at the stack root with nothing behind it — no back button.

2. **`ride_status_screen.dart`** — the AppBar's `BackButton`, the cancel-success handler, and both "Back to My Rides" buttons in the expired/cancelled states all called `context.go(AppRoutes.myRides)`, which always replaced the stack. The `_goBack()` helper added in a previous session was added but the two buttons in the expired/cancelled body were not updated (the previous session's multi-replace failed silently).

3. **`my_rides_screen.dart`** — had no explicit `leading:` in the AppBar, so Flutter's `automaticallyImplyLeading` hid the back button when the screen was the stack root.

### Fixes applied

| File | Change |
|------|--------|
| `lib/features/ride_request/ride_request_screen.dart` | `context.go` → `context.push` after submit (already fixed in prior session — verified present) |
| `lib/features/ride_status/ride_status_screen.dart` | The two remaining `context.go(AppRoutes.myRides)` in `_expiredBody` and `_cancelledBody` replaced with `_goBack()` |
| `lib/features/my_rides/my_rides_screen.dart` | Added explicit `leading: IconButton` with `canPop() ? pop() : go(home)` — back button always visible |

### Navigation invariant (all screens)

| Call | When to use |
|------|-------------|
| `context.push` | Forward navigation (Home→MyRides, MyRides→Status, etc.) |
| `context.pop` / `_goBack()` | Backward navigation |
| `context.go` | Auth-root resets only (sign-out → login, register success → home) |

- `flutter analyze lib` → **No issues**

---

## ✅ Bug fix — Barikoi autocomplete returns no results (DONE)

**Date:** 2026-10-28

### Root cause

The `BarikoiGeocodingService.search()` method was written against an assumed response
shape that didn't match the real Barikoi API response.

**Real response:**
```json
{"places":[{"id":null,"longitude":"90.38","latitude":"23.86",
            "address":"Uttara, Dhaka","uCode":"XUSWI61626"}]}
```

Problems found:

| Problem | Detail |
|---------|--------|
| `name` always empty | Code tried `p['address_bn']` first (absent), then `p['address']` — but assigned it to `name`, not `address`. |
| `address` always empty | Built from `p['address']`, `p['area']`, `p['city']` — `area`/`city` absent in autocomplete; joined to `''`. |
| `displayLabel` is `''` | `LocationResult.displayLabel` = `name ?? address` → both empty → blank list tiles. |
| Silent failures | All errors (network, non-200) swallowed by `catch (_) { return []; }` — no logs, no user feedback. |
| `id` field used as key | `id` is `null` in the real response; not used for display but bad practice. |
| Min-chars threshold | `location_search_sheet.dart` triggered searches at 2 characters; spec requires 3. |
| No debug logging | Raw HTTP response was never printed, making network issues invisible. |

### Fixes applied

#### `lib/core/location/barikoi_geocoding_service.dart`

- **`_placeToResult()` helper**: correctly reads `"address"` as the primary display
  label; builds a richer joined string only when optional sub-fields exist.
- **`double.tryParse`** on `latitude`/`longitude` strings (was already done; confirmed safe).
- **Does not use `"id"`** (null in real responses).
- **`search()` now throws `GeocodingException`** on non-200 HTTP response (with `statusCode`)
  and on network errors — instead of returning `[]` silently.
- **`reverseGeocode()` stays non-throwing** (returns null on failure) — pin can remain
  unlabelled without blocking the user.
- **`debugPrint`** logs the raw response body and status code on every call.
- **`BARIKOI_API_KEY`** is already read via `String.fromEnvironment('BARIKOI_API_KEY')`
  in `AppEnv` and passed to the service from `geocodingServiceProvider` — no change needed.

#### `lib/features/ride_request/widgets/location_search_sheet.dart`

- **3-character minimum** (`_minChars = 3`): searches only fire when `query.trim().length >= 3`.
- **400 ms debounce** (`_debounceMs = 400`): unchanged; confirmed present.
- **`_error` state**: catches `GeocodingException` (and any other exception) and stores
  a human-readable message including the HTTP status code.
- **Visible error banner**: shown with a red `Icons.error_outline_rounded` icon and the
  status code text (e.g. "Search failed (HTTP 401). Check your connection.").
- **"No results"** message: shown when results list is empty and ≥ 3 chars typed.
- **"Type at least 3 characters"** hint: shown when 1–2 chars typed.
- **Loading spinner**: unchanged; confirmed present.

#### `GeocodingException` class (in `barikoi_geocoding_service.dart`)

New lightweight exception class:
```dart
class GeocodingException implements Exception {
  final String message;
  final int? statusCode; // present on non-200 HTTP responses
}
```

### No changes to
- `env.json` — `BARIKOI_API_KEY` was already present.
- `core/env.dart` — `AppEnv.barikoiApiKey` already reads via `String.fromEnvironment`.
- `geocoding_provider.dart` — still passes `AppEnv.barikoiApiKey` to the service.
- `geocoding_service.dart` — abstract interface unchanged.
- `nominatim_geocoding_service.dart` — unaffected.

- `flutter analyze lib` → **No issues**

---

## ⏭️ Step 9 — Driver Mode Screens (NEXT)

**What to do manually before Step 9:**
1. Run `supabase db push` to apply migrations 006–010 (if not already applied).
2. Test the status screen:
   - Run `supabase/test_status_flow.sql` in the Supabase SQL editor.
   - Copy a `group_id` from the SELECT result.
   - Uncomment and run each UPDATE (replacing `'YOUR-GROUP-ID-HERE'` with the real UUID) while watching the app.
3. Commit: `git add . && git commit -m "Step 8 complete + nav fix + auth fix + R8 fix"`

### Release build command (always use this)
```powershell
flutter build apk --release --dart-define-from-file=env.json
```
> ⚠️ **Never omit `--dart-define-from-file=env.json`** — the app will crash without API keys.
>
> ⚠️ **Keep `isMinifyEnabled = false` and `isShrinkResources = false`** in `android/app/build.gradle.kts` — R8 breaks `shared_preferences_android` at runtime.

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
| 7 | Matching engine (PostGIS SQL function) | Done |
| 8 | Realtime group status screen | Done |
| 9 | Driver mode screens | **Next** |
| 10 | Live tracking + ORS route distance in matching | - |
| 11 | Push notifications (FCM) | - |
| 12 | Payments (cash + bKash/Nagad) | - |
| 13 | Ratings, SOS, admin panel | - |
| 14 | Driver auto-assign, Bangla i18n, beta | - |
