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
  - `handle_new_user()` function (`SECURITY DEFINER`) — fires on every `auth.users` INSERT
  - Reads `name`, `phone`, `role` from signup metadata and inserts a `public.users` row
  - `on_auth_user_created` trigger attached to `auth.users`

#### Flutter — new files
| File | Purpose |
|------|---------|
| `lib/core/supabase/supabase_client_provider.dart` | Riverpod `Provider<SupabaseClient>` wrapping the singleton |
| `lib/features/auth/data/auth_repository.dart` | `AuthRepository`: sign up, sign in, sign out; returns `AuthResult` (never throws) |
| `lib/features/auth/providers/auth_providers.dart` | `authStateProvider` (Stream), `currentUserProvider` (sync User?) |
| `lib/features/auth/register_screen.dart` | Registration: name, email, phone, password, rider/driver role picker |

#### Flutter — updated files
| File | Change |
|------|--------|
| `lib/features/auth/login_screen.dart` | Replaced placeholder → real email+password form, loading state, error banner |
| `lib/core/router/app_router.dart` | Added `/register` route; auth-guarded redirect via `_AuthChangeNotifier` + `refreshListenable` |
| `lib/main.dart` | Uncommented `Supabase.initialize`; `ShareGariApp` → `ConsumerWidget` passes `WidgetRef` to `createRouter` |
| `lib/features/home/home_screen.dart` | `ConsumerWidget`; reads `currentUserProvider` for greeting; sign-out button wired to `AuthRepository.signOut()` |

- `flutter analyze lib` — **No issues found**

### Auth flow
1. App starts → `Supabase.initialize` restores persisted session (if any)
2. GoRouter redirect: unauthenticated → `/login`; signed-in visiting login/register → `/`
3. `/login` → email+password sign-in → navigates to `/`
4. `/register` → fills form → `AuthRepository.signUpWithEmail` → Postgres trigger creates `public.users` → navigates to `/`
5. Home screen sign-out button → `AuthRepository.signOut()` → router redirects to `/login`

### Before running Step 3
1. Run `supabase/migrations/002_auth_trigger.sql` in Supabase SQL editor
2. In Supabase dashboard → **Authentication → Settings** → disable "Confirm email" for development (so signup completes immediately without email confirmation)
3. Then run: `flutter run --dart-define-from-file=env.json`

### Known issues / TODOs
- Email login is a dev shortcut. Phone OTP will replace it (Step 3b or later) once an SMS provider is set up.
- `Supabase.initialize` uses `anonKey:` which is internally deprecated in favour of `publishableKey:`; suppressed with `// ignore:` until the package renames the parameter in a major version.
- `currentUserProvider` is synchronous — on first cold start after session restore, there's a brief moment where it returns null before the stream fires. The router handles this via `authValue.isLoading` check.

---

## ⏭️ Step 4 — Map and Location Picking (NEXT)

**Prompt to use:**
> "Add flutter_map with OpenStreetMap tiles to the Request Ride screen. Let the user pick pickup and drop-off by tapping the map and by searching with Barikoi. Wrap geocoding behind an abstract service interface. Use a free-tier tile provider, keep the API keys in a config file excluded from git."

**What to do manually before Step 4:**
1. Run `supabase/migrations/002_auth_trigger.sql` in Supabase SQL editor
2. Disable email confirmation in Supabase Auth settings
3. Test the full auth flow: register → home → sign out → sign in
4. Commit: `git add . && git commit -m "Step 3 done"`

---

## Upcoming steps (reference)

| Step | Topic | Status |
|------|-------|--------|
| 1 | Project skeleton, Riverpod, GoRouter, theme, placeholder screens | Done |
| 2 | Supabase SQL migration + PostGIS + RLS | Done |
| 3 | Supabase auth (email dev, phone OTP later) | Done |
| 4 | flutter_map + OpenStreetMap + Barikoi geocoding | Next |
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
