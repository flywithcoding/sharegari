# PRD: Shared Ride App (working name: "ShareGari")

## 1. Overview
A mobile app where riders in Dhaka request a ride by entering a start point, an end point, and a departure time. The system groups up to 4 riders with similar time windows and nearby routes into one shared car, and splits the fare. Example: a ride that costs 500 BDT alone costs about 125 BDT per person when 4 share.

## 2. Problem
Ride-hailing (Uber, Pathao, etc.) is expensive for daily commuters who travel similar routes at similar times. Cars run with 1 passenger while many people make the same trip.

## 3. Goals
- Cut per-person cost by 50-75% versus a solo ride.
- Match riders automatically with minimal detour (max ~10 minutes extra per rider).
- Simple booking: under 30 seconds to request a ride.

### Non-goals (MVP)
- Intercity rides, scheduling more than 24 hours ahead, ride-sharing between private car owners, in-app chat with drivers.

## 4. Target Users
- **Rider:** office workers and students commuting on repeating routes in Dhaka.
- **Driver:** professional drivers (own car or partner fleet) who earn more per trip by carrying 3-4 paying riders.
- **Admin:** operations team monitoring matches, pricing, disputes.

## 5. Tech Stack (decided)
- **Mobile app: Flutter (Dart)**, Android first, iOS second. Reasons: native GPS/background location, push notifications, and map performance; one codebase; Android dominates in Bangladesh.
- **Backend:** Supabase (PostgreSQL + PostGIS for geo queries, Auth with phone OTP, Realtime, Edge Functions). Alternative: Node.js (NestJS) + PostgreSQL/PostGIS.
- **Maps/Routing (free stack):** `flutter_map` + OpenStreetMap-based tiles (MapTiler/Stadia free tier at launch; self-host later). Routing/ETA via OpenRouteService free tier, later self-hosted OSRM or Valhalla with the Bangladesh OSM extract. Place search/geocoding via Barikoi (Bangladesh-focused, free tier), with Photon/Nominatim as fallback (respect rate limits). No Google Maps dependency.
- **Notifications:** Firebase Cloud Messaging; SMS OTP via a local provider (e.g., SSL Wireless / Twilio).
- **Payments:** bKash and Nagad via an aggregator (SSLCommerz or aamarPay), plus cash option in MVP.
- **Admin panel:** simple React web dashboard (internal only).

## 6. Core User Flows

### 6.1 Rider
1. Sign up with phone number + OTP.
2. Tap "Request Shared Ride".
3. Choose pickup (map pin or search), drop-off, and departure time (with flexible window: +/- 10 / 15 / 20 minutes).
4. See estimated solo price vs. estimated shared price (range, e.g. 125-200 BDT).
5. Confirm request. Status: "Finding riders".
6. Receive push notification when a group is formed (co-rider count, pickup time, pickup point, driver and car details, final fare).
7. Ride happens: live tracking of driver, share trip link with family.
8. Pay (bKash/Nagad/cash), rate driver and co-riders.

### 6.2 Driver
1. Register, upload NID, license, car details; admin approves.
2. Go online, receive assigned shared-ride groups with ordered pickup/drop-off route and earnings.
3. Accept/decline, navigate stop by stop, mark each rider picked up/dropped.

### 6.3 Admin
View requests, matches, unmatched riders, pricing config, driver approvals, complaints, refunds.

## 7. Functional Requirements

### 7.1 Ride Request
- Fields: pickup (lat/lng + address), drop-off, desired departure time, time flexibility, seats (1 in MVP).
- Request expires if no match 15 minutes before the departure time; rider is notified and offered a solo ride fallback (deep link to Uber/Pathao) or a different time.

### 7.2 Matching Engine
- Runs every 1-2 minutes for requests departing in the next 60 minutes.
- Two requests are compatible when:
  - Time windows overlap.
  - Pickup points within 1.5 km of each other (configurable).
  - Drop-off points within 2 km of each other, OR drop-offs lie along the main route (detour for any rider <= 10 min).
- Group size 2-4. Prefer groups of 4. If only 2-3 are found by T-20 min, confirm the smaller group at a higher per-person price (never above 60% of the solo price).
- Algorithm (MVP): cluster by geohash/PostGIS distance, then order stops via a greedy route (or Google Directions waypoint optimization); reject groups exceeding the detour limit.
- Corridor mode (recommended launch strategy): launch with a small set of popular fixed corridors (e.g., Uttara -> Motijheel, Mirpur -> Gulshan) at fixed time slots so matches are dense.

### 7.3 Pricing and Fare Split
- Base: estimated solo fare from distance/time (distance x per-km rate + base fare).
- Shared fare per rider = solo fare of the full route x sharing factor / group size, plus a small platform fee (default 10%).
- Fare is calculated at confirmation and locked. Show price to each rider before they commit.
- Riders with a longer individual leg may pay proportionally more (phase 2: proportional-by-distance split).

### 7.4 Driver Assignment
- Nearest available approved driver with matching car capacity (4 passengers) is offered the group; timeout 60s then next driver.

### 7.5 Live Tracking
- Real-time driver location on rider map; ETA to each pickup.
- Rider can share trip link.

### 7.6 Payments
- bKash/Nagad payment after trip completion or pre-authorized at confirmation.
- Cash accepted in MVP; driver reports cash received.
- Driver payout weekly/daily via mobile banking.

### 7.7 Ratings and Safety
- Mutual ratings (rider <-> driver, rider <-> co-riders).
- SOS button (calls emergency number and notifies trusted contact).
- Show co-rider first name only; no phone numbers shared.
- Women-only ride option (phase 2).
- Report issue / cancel flow with cancellation fee after group confirmation.

### 7.8 Notifications
Request received, group found, driver assigned, driver arriving, trip started, trip completed, payment receipt.

## 8. Data Model (high level)
- `users` (id, name, phone, role, rating)
- `drivers` (user_id, nid, license, car_model, plate, status, location)
- `ride_requests` (id, rider_id, pickup_geo, drop_geo, depart_at, window_min, status)
- `ride_groups` (id, driver_id, status, route_json, fare_total, depart_at)
- `group_members` (group_id, request_id, fare, pickup_order, dropoff_order, status)
- `payments` (id, member_id, method, amount, status, provider_ref)
- `ratings`, `incidents`, `pricing_config`

## 9. Non-Functional Requirements
- Match latency: new request evaluated within 2 minutes.
- App cold start < 3 s on mid-range Android; works on Android 8+.
- Handles 5,000 concurrent users at launch scale.
- Encrypted data in transit and at rest; compliance with Bangladesh data/privacy requirements.
- Bangla and English UI.
- Works on poor networks: retry queues, low-data map mode.

## 10. MVP Scope
In: phone auth, request ride, matching for corridors, driver app (same Flutter codebase with role switch), fare split, cash + bKash, push notifications, live tracking, ratings, basic admin panel.
Out: iOS polish, women-only rides, subscriptions/passes, recurring daily rides (phase 2), in-app chat.

## 11. Success Metrics
- Match rate: >= 70% of requests matched.
- Average group size >= 3.2.
- Average rider savings >= 50% vs solo ride.
- Week-4 rider retention >= 30%.
- Rider NPS >= 40; driver cancellation rate < 8%.

## 12. Risks and Open Questions
- **Cold start (chicken-and-egg):** not enough riders for matches. Mitigation: corridor launch, fixed time slots, campus/office partnerships.
- **Regulation:** check BRTA rules for ride-sharing and commercial licensing for drivers/cars.
- **Driver economics:** 4 x 125 = 500 BDT may not beat a normal fare for the driver after platform fee; consider total shared fare of 600-700 BDT with each rider paying 150-175 BDT. Validate with real drivers.
- **Safety/trust** among strangers; mitigated by verification, ratings, SOS.
- **No-shows:** cancellation penalties and rating impact.

## 13. Milestones
1. Week 1-2: design, data model, auth, maps integration.
2. Week 3-5: request flow, matching engine v1, fare calculation.
3. Week 6-7: driver app flow, live tracking, notifications.
4. Week 8: payments (bKash/Nagad), admin panel.
5. Week 9-10: closed beta on 1-2 corridors, fix, iterate.
6. Week 11-12: public launch on pilot corridors.

## 14. Instructions for Antigravity
- Create a Flutter project with feature-first folder structure (`features/auth`, `features/ride_request`, `features/matching`, `features/driver`, `features/payments`).
- Use Riverpod for state management, GoRouter for navigation, and the Supabase Flutter SDK. Use `flutter_map` (not Google Maps) for all map screens, and wrap routing/geocoding behind an abstract service interface so providers can be swapped without changing UI code.
- Start by building: auth (phone OTP), ride request screen with map picker, and a mock matching service; then replace the mock with the Supabase/PostGIS matching function.
- Write unit tests for the fare split and matching compatibility rules.
