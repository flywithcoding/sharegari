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
- Created `env.json` with required key names (replace placeholder values with real keys from your Supabase / ORS / Barikoi / MapTiler dashboards)
- Created `env.example.json` with placeholder values for teammates
- Added `env.json` to `.gitignore`
- `flutter pub get` — OK (113 deps resolved)
- `flutter analyze lib` — No issues found

### How to run

```sh
flutter run --dart-define-from-file=env.json
```

### Known issues / TODOs
- AppEnv.assertAll() calls assert() which only fires in debug mode. In Step 3, add a startup validation that also works in profile/release builds.
- Supabase.initialize is commented out in main.dart — Step 3 will uncomment it once real keys are in env.json.
- google_fonts makes a network call for fonts on first run. Consider bundling them as assets later.

---

## ⏭️ Step 2 — Database (NEXT)

Prompt to use:
> "Write one SQL migration file for Supabase with the tables from the PRD data model, enable PostGIS, and add Row Level Security policies so users only see their own data. Do not touch the Flutter code yet."

What to do manually before Step 2:
1. Fill in `env.json` with real values from your Supabase project and other providers.
2. Test the app runs: `flutter run --dart-define-from-file=env.json`
3. Commit: `git add . && git commit -m "Step 1 done"`

---

## Upcoming steps (reference)

| Step | Topic | Status |
|------|-------|--------|
| 1 | Project skeleton, Riverpod, GoRouter, theme, placeholder screens | Done |
| 2 | Supabase SQL migration + PostGIS + RLS | Next |
| 3 | Supabase auth (email dev, phone OTP later) | - |
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
