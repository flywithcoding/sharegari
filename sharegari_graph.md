# ShareGari — Codebase Graph

> **ShareGari** is a Flutter shared-ride app for Dhaka commuters.  
> Stack: Flutter + Riverpod + GoRouter + Supabase (PostGIS) + OpenRouteService

---

## 1. High-Level Architecture

```mermaid
graph TD
    subgraph Flutter["Flutter App"]
        MAIN["main.dart\nProviderScope · Supabase.init()"]
        ROUTER["core/router/app_router.dart\nGoRouter · Auth-guarded redirect"]
        THEME["core/theme/app_theme.dart\nMaterial dark theme"]

        subgraph Features["Features"]
            AUTH["auth/"]
            HOME["home/"]
            RREQ["ride_request/"]
            RSTATUS["ride_status/"]
            MYRIDES["my_rides/"]
            DRIVER["driver/ (stub)"]
            MATCHING["matching/ (stub)"]
            PAYMENTS["payments/ (stub)"]
        end

        subgraph Core["Core Services"]
            ENV["core/env.dart\nAppEnv (dart-define)"]
            SB_PROV["core/supabase/\nsupabaseClientProvider"]
            LOC["core/location/\nGeocodingService + LocationResult"]
            PRICING["core/pricing/\nFareCalculator + PricingConfig"]
            ROUTING["core/routing/\nRoutingService → ORS"]
        end
    end

    subgraph Supabase["Supabase Backend (PostgreSQL + PostGIS)"]
        DB["PostgreSQL DB\n(12 migrations)"]
        RLS["Row Level Security"]
        RT["Realtime\n(Supabase Streams)"]
        MATCH_FN["run_matching()\nSQL Matching Engine"]
    end

    MAIN --> ROUTER
    MAIN --> THEME
    ROUTER --> Features
    Features --> Core
    Core --> Supabase
```

---

## 2. App Routing & Navigation

```mermaid
flowchart LR
    START(["App Start"]) --> COLDSTART{"Auth stream\nloading?"}
    COLDSTART -- "isLoading" --> STAY["Stay put (re-eval on next emit)"]
    COLDSTART -- "hasValue" --> SIGNEDIN{"User\nsigned in?"}

    SIGNEDIN -- "No + public route" --> NOOP["No redirect"]
    SIGNEDIN -- "No + private route" --> LOGIN["/login\nLoginScreen"]
    SIGNEDIN -- "Yes + public route" --> HOMEDIR["/home\nHomeScreen"]
    SIGNEDIN -- "Yes + private route" --> NOOP

    LOGIN --> REGISTER["/register\nRegisterScreen"]
    LOGIN --> HOMEDIR

    HOMEDIR --> RREQR["/ride-request\nRideRequestScreen"]
    HOMEDIR --> MYRIDES["/my-rides\nMyRidesScreen"]
    MYRIDES --> RSTATUS["/ride-status/:requestId\nRideStatusScreen"]
    RREQR --> RSTATUS
```

**Route constants** — [`AppRoutes`](file:///e:/WorkSpace/AntiGravity/sharegari/lib/core/router/app_router.dart#L13-L27)

| Route | Screen |
|---|---|
| `/login` | `LoginScreen` |
| `/register` | `RegisterScreen` |
| `/` | `HomeScreen` |
| `/ride-request` | `RideRequestScreen` |
| `/my-rides` | `MyRidesScreen` |
| `/ride-status/:requestId` | `RideStatusScreen` |

---

## 3. Riverpod Provider Dependency Graph

```mermaid
graph TD
    %% Foundation
    SB_CLIENT["supabaseClientProvider\nProvider&lt;SupabaseClient&gt;"]

    %% Auth layer
    AUTH_REPO["authRepositoryProvider\nProvider&lt;AuthRepository&gt;"]
    AUTH_STATE["authStateProvider\nStreamProvider&lt;AuthState&gt;"]
    AUTH_USER["authUserProvider\nStreamProvider&lt;User?&gt;"]
    CURR_USER["currentUserProvider\nProvider&lt;User?&gt;"]

    %% Pricing layer
    PRICING_REPO["pricingConfigProvider\nAsyncNotifierProvider&lt;PricingConfig&gt;"]
    PRICING_SYNC["pricingConfigSyncProvider\nProvider&lt;PricingConfig&gt;"]
    FARE_CALC["fareCalculatorProvider\nProvider&lt;FareCalculator&gt;"]

    %% Location layer
    GEO_SVC["geocodingServiceProvider\nProvider&lt;GeocodingService&gt;"]

    %% Ride Request layer
    RREQ_REPO["rideRequestRepositoryProvider\nProvider&lt;RideRequestRepository&gt;"]
    MY_RIDES["myRidesProvider\nStreamProvider&lt;List&lt;RideRequest&gt;&gt;"]

    %% Ride Status layer
    RSTATUS_REPO["rideStatusRepositoryProvider\nProvider&lt;RideStatusRepository&gt;"]
    REQ_STATUS["requestStatusStreamProvider\nStreamProvider.family&lt;String, String&gt;"]
    GROUP_DETAIL["groupDetailProvider\nFutureProvider.family&lt;GroupDetail?, String&gt;"]
    GROUP_STATUS["groupStatusStreamProvider\nStreamProvider.family&lt;String, String&gt;"]

    %% Wiring
    SB_CLIENT --> AUTH_REPO
    SB_CLIENT --> RREQ_REPO
    SB_CLIENT --> RSTATUS_REPO
    SB_CLIENT --> PRICING_REPO

    AUTH_REPO --> AUTH_STATE
    AUTH_REPO --> AUTH_USER
    AUTH_USER --> CURR_USER

    PRICING_REPO --> PRICING_SYNC
    PRICING_SYNC --> FARE_CALC

    RREQ_REPO --> MY_RIDES

    RSTATUS_REPO --> REQ_STATUS
    RSTATUS_REPO --> GROUP_DETAIL
    RSTATUS_REPO --> GROUP_STATUS

    %% GoRouter refreshListenable
    AUTH_USER -. "refreshListenable" .-> ROUTER["createRouter()\nGoRouter"]
```

---

## 4. Feature Module Breakdown

### 4.1 `auth/`

```
auth/
├── login_screen.dart          — Email/password sign-in UI
├── register_screen.dart       — Sign-up with name/phone/role
├── data/
│   └── auth_repository.dart   — AuthRepository (signUp, signIn, signOut)
└── providers/
    └── auth_providers.dart    — authStateProvider, authUserProvider, currentUserProvider
```

**Key class:** [`AuthRepository`](file:///e:/WorkSpace/AntiGravity/sharegari/lib/features/auth/data/auth_repository.dart#L21-L96) — wraps `SupabaseClient.auth`; never throws, returns `AuthResult`.

---

### 4.2 `ride_request/`

```
ride_request/
├── ride_request_screen.dart   — Map + form to submit a new ride request
├── data/
│   ├── ride_request_model.dart     — RideRequest, RideRequestStatus enum
│   └── ride_request_repository.dart — insert(), cancel(), fetchMyRides(), watchMyRides()
├── providers/
│   └── ride_request_providers.dart — myRidesProvider (Realtime stream)
└── widgets/
    ├── map_picker.dart              — FlutterMap with draggable marker
    └── location_search_sheet.dart   — Geocoding search bottom sheet
```

**Key flows:**
- Rider picks pickup & drop on map → geocoded via `GeocodingService`
- `OrsRoutingService` fetches route distance/duration
- `FareCalculator.estimateRange()` shows fare estimate (BDT range)
- Confirmed → `RideRequestRepository.insert()` → Supabase; navigates to `RideStatusScreen`

---

### 4.3 `ride_status/`

```
ride_status/
├── ride_status_screen.dart    — Live status tracker (28 KB, most complex screen)
├── data/
│   ├── ride_status_models.dart     — GroupStatus enum, CoRider, DriverDetail, GroupDetail
│   └── ride_status_repository.dart — watchRequestStatus(), fetchGroupDetail(), watchGroupStatus(), cancelRequest()
└── providers/
    └── ride_status_providers.dart  — requestStatusStreamProvider, groupDetailProvider, groupStatusStreamProvider
```

**Status state machine:**

```mermaid
stateDiagram-v2
    [*] --> searching : Request inserted
    searching --> matched : run_matching() groups rider
    searching --> expired : departure < now + 15min
    matched --> confirmed : driver accepts
    confirmed --> in_progress : trip starts
    in_progress --> completed : trip ends
    searching --> cancelled : rider cancels
    matched --> cancelled : rider cancels (group dissolved → others re-queue)
```

---

### 4.4 `my_rides/`

Single screen [`MyRidesScreen`](file:///e:/WorkSpace/AntiGravity/sharegari/lib/features/my_rides/my_rides_screen.dart) — live list of all of the rider's requests via `myRidesProvider` (Supabase Realtime `.stream()`).

---

### 4.5 Stub Features (placeholder files only)

| Feature | File | Status |
|---|---|---|
| `driver/` | `driver.dart` | Stub |
| `matching/` | `matching.dart` | Stub |
| `payments/` | `payments.dart` | Stub |

---

## 5. Core Services

### 5.1 Location / Geocoding

```mermaid
graph LR
    GEO_PROV["geocodingServiceProvider"] -- "barikoiApiKey set?" --> BARIKOI["BarikoiGeocodingService\n(Barikoi API)"]
    GEO_PROV -- "fallback" --> NOMINATIM["NominatimGeocodingService\n(OSM Nominatim)"]
    BARIKOI & NOMINATIM --> IFACE["GeocodingService\n(abstract)\n.search()\n.reverseGeocode()"]
    IFACE --> LOC_MODEL["LocationResult\n{ latLng, address, name }"]
```

### 5.2 Routing (ORS)

```
core/routing/
├── routing_service.dart     — abstract RoutingService { getRoute(), getRouteMulti() }
└── ors_routing_service.dart — OpenRouteService HTTP impl; returns OrsRouteResult
```

`OrsRouteResult` exposes `.distanceKm` and `.durationMin` for fare computation.

### 5.3 Pricing

```mermaid
graph LR
    DB_ROW["Supabase\npricing_config"] --> NOTIFIER["PricingConfigNotifier\n(AsyncNotifier)"]
    NOTIFIER --> SYNC["pricingConfigSyncProvider\n(returns fallback until loaded)"]
    SYNC --> CALC["FareCalculator\n.carFare()\n.riderFare()\n.estimateRange()\n.soloFare()"]
    CALC --> RANGE["FareRange\n{ low, high }\n→ '৳125 – ৳250'"]
```

**Fare formula:**
```
car_fare  = max(min_fare, base + per_km × km + per_min × min)
rider_fare = roundUp5(car_fare / n_riders × (1 + platform_fee_pct))
```

---

## 6. Database Schema (PostgreSQL + PostGIS)

```mermaid
erDiagram
    auth_users {
        uuid id PK
    }
    users {
        uuid id PK
        text name
        text phone
        user_role role
        numeric rating
    }
    drivers {
        uuid user_id PK
        text car_model
        text plate
        int seat_capacity
        driver_status status
        bool is_online
        geography location
    }
    ride_requests {
        uuid id PK
        uuid rider_id FK
        geography pickup_geo
        text pickup_address
        float pickup_lat
        float pickup_lng
        geography drop_geo
        text drop_address
        float drop_lat
        float drop_lng
        timestamptz depart_at
        int window_min
        request_status status
        numeric estimated_solo_fare
        numeric estimated_share_fare
    }
    ride_groups {
        uuid id PK
        uuid driver_id FK
        group_status status
        jsonb route_json
        numeric fare_total
        timestamptz depart_at
    }
    group_members {
        uuid id PK
        uuid group_id FK
        uuid request_id FK
        numeric fare
        int pickup_order
        int dropoff_order
        member_status status
    }
    payments {
        uuid id PK
        uuid member_id FK
        payment_method method
        numeric amount
        payment_status status
    }
    ratings {
        uuid id PK
        uuid group_id FK
        uuid rater_id FK
        uuid ratee_id FK
        int score
    }
    incidents {
        uuid id PK
        uuid group_id FK
        uuid reporter_id FK
        text description
    }
    pricing_config {
        int id PK
        numeric base_fare_bdt
        numeric per_km_rate_bdt
        numeric per_min_rate_bdt
        numeric min_fare_bdt
        numeric platform_fee_pct
        int max_pickup_radius_m
        int max_dropoff_radius_m
        int matching_window_min
    }

    auth_users ||--|| users : "1-to-1"
    users ||--o| drivers : "has driver profile"
    users ||--o{ ride_requests : "places"
    users ||--o{ ratings : "rates"
    users ||--o{ incidents : "reports"
    drivers ||--o{ ride_groups : "assigned to"
    ride_requests ||--o{ group_members : "placed in"
    ride_groups ||--o{ group_members : "has"
    group_members ||--o| payments : "paid via"
    ride_groups ||--o{ ratings : "has"
    ride_groups ||--o{ incidents : "related to"
```

---

## 7. Matching Engine (`run_matching()`)

Lives entirely in SQL ([`007_matching_engine_schema.sql`](file:///e:/WorkSpace/AntiGravity/sharegari/supabase/migrations/007_matching_engine_schema.sql)).

```mermaid
flowchart TD
    CRON["pg_cron / Edge Function\nevery 1 minute"] --> RUN["run_matching()"]

    RUN --> LOAD["1. Load pricing_config"]
    LOAD --> EXPIRE["2. Expire stale 'searching' requests\n(depart_at ≤ now + expire_before_min)"]
    EXPIRE --> ITER["3. Iterate 'searching' requests\n(FOR UPDATE SKIP LOCKED)"]
    ITER --> CANDS["4. Find ≤ 3 compatible candidates\n• Time window overlap\n• Pickup within max_pickup_radius_m\n• Drop-off within max_dropoff_radius_m\n• Greedy nearest-neighbour"]
    CANDS --> CHECK{">= 2 riders?"}
    CHECK -- No --> NEXT["Next anchor request"]
    CHECK -- Yes --> FARE["5. Compute fare\nstraight-line × 1.30 detour factor"]
    FARE --> GROUP["6. INSERT ride_groups\n(status = 'pending_driver')"]
    GROUP --> MEMBERS["7. INSERT group_members\n+ UPDATE ride_requests → 'matched'"]
    MEMBERS --> NEXT
    NEXT --> DONE["Return JSONB summary\n{ groups_formed, riders_matched, riders_expired }"]
```

**PostGIS functions used:** `ST_DWithin()`, `ST_Distance()` (geography sphere metres)

---

## 8. Migration Timeline

| # | File | Key Changes |
|---|---|---|
| 001 | `001_initial_schema.sql` | Full schema, enums, RLS, `pricing_config` seed |
| 002 | `002_auth_trigger.sql` | Postgres trigger: auto-insert `public.users` on `auth.users` insert |
| 003 | `003_pricing_v2.sql` | Adds `per_min_rate_bdt`, `min_fare_bdt` to `pricing_config` |
| 004 | `004_geo_latlong_columns.sql` | Adds generated `pickup_lat/lng`, `drop_lat/lng` columns (avoids hex EWKB) |
| 005 | `005_realtime_publication.sql` | Enables Supabase Realtime on `ride_requests`, `ride_groups` |
| 006 | `006_matching_engine.sql` | Adds `'searching'` & `'pending_driver'` enum values |
| 007 | `007_matching_engine_schema.sql` | `run_matching()` SQL function + `matching_window_min` config |
| 008 | `008_fix_phone_nullable.sql` | Makes `phone` nullable (optional at signup) |
| 009 | `009_fix_uuid_generate.sql` | Fixes `uuid_generate_v4()` availability on all Supabase plans |
| 010 | `010_rider_status_screen.sql` | `my_group_co_riders` view; `cancel_ride_request()` function |
| 011 | `011_matching_lookahead_and_dates.sql` | `run_matching()` 7-day lookahead, cross-date isolation, 15-min expiry |
| 012 | `012_open_groups_prebooking.sql` | Open groups for pre-booking, price drop on join, 120-min cutoff |

---

## 9. Key External Dependencies

| Package | Version | Purpose |
|---|---|---|
| `flutter_riverpod` | ^2.6.1 | State management |
| `riverpod_annotation` | ^2.5.2 | Code-gen annotations |
| `go_router` | ^14.6.2 | Declarative navigation |
| `supabase_flutter` | ^2.8.1 | Auth, DB, Realtime |
| `flutter_map` | ^7.0.2 | OSM map rendering |
| `latlong2` | ^0.9.1 | `LatLng` type |
| `http` | ^1.2.2 | Barikoi / Nominatim / ORS HTTP calls |
| `google_fonts` | ^6.2.1 | Typography |
| `intl` | ^0.20.1 | Date formatting in MyRidesScreen |

---

## 10. Data Flow: End-to-End Ride Request

```mermaid
sequenceDiagram
    actor Rider
    participant UI as RideRequestScreen
    participant GEO as GeocodingService
    participant ORS as OrsRoutingService
    participant FARE as FareCalculator
    participant REPO as RideRequestRepository
    participant DB as Supabase DB
    participant ENGINE as run_matching()
    participant STATUS as RideStatusScreen

    Rider->>UI: Picks pickup & drop on map
    UI->>GEO: reverseGeocode(LatLng)
    GEO-->>UI: LocationResult (address)
    UI->>ORS: getRoute(pickup, drop)
    ORS-->>UI: OrsRouteResult (km, min)
    UI->>FARE: estimateRange(km, min)
    FARE-->>UI: FareRange (low/high BDT)
    Rider->>UI: Confirms ride
    UI->>REPO: insert(RideRequest)
    REPO->>DB: INSERT ride_requests (status='searching')
    DB-->>REPO: Created row
    REPO-->>UI: RideRequest
    UI->>STATUS: context.go('/ride-status/:id')

    loop Every ~1 minute (cron/Edge Fn)
        ENGINE->>DB: run_matching()
        DB-->>ENGINE: Groups formed
        DB->>STATUS: Realtime: status → 'matched'
    end

    STATUS->>DB: watchRequestStatus(id) [Realtime stream]
    DB-->>STATUS: status = 'matched'
    STATUS->>DB: fetchGroupDetail(id)
    DB-->>STATUS: GroupDetail (co-riders, driver, fare)
    STATUS->>DB: watchGroupStatus(groupId) [Realtime stream]
    DB-->>STATUS: group status updates…
```
