# Build Plan: Work in Small Steps (for limited AI quota)

## Golden rules
1. **One step per session.** Never ask the AI to "build the whole app".
2. **Keep `PRD.md` and `PROGRESS.md` in the project root.** `PROGRESS.md` is the memory between sessions.
3. **Start every session with this prompt (replace X):**
   > Read PRD.md and PROGRESS.md. Do ONLY Step X from BUILD_PLAN.md. Keep changes small and make sure the app runs. At the end, update PROGRESS.md with what is done, what is next, and any known bugs.
4. **Commit to git after every step** (`git add . && git commit -m "Step X done"`). If the AI breaks something, you can go back.
5. **If the limit hits mid-step:** ask it (if you still can) "Update PROGRESS.md with exactly where you stopped." Next session, start with the prompt above and say "continue Step X".
6. **Test on a real phone or emulator after each step** before moving on. Paste exact error messages back to the AI instead of describing them.
7. **Use mock data first, real services later.** This saves quota and avoids debugging two things at once.

## Step 0: Setup (you do this, no AI quota needed)
- Install Flutter SDK, Android Studio (with emulator), VS Code or Antigravity.
- Create a free Supabase project (note the URL and anon key).
- Create free accounts for OpenRouteService and Barikoi (API keys).
- Create a GitHub repo, `git init`.
- Put `PRD.md` in the project folder and create an empty `PROGRESS.md`.

## Step 1: Project skeleton
Prompt: "Create the Flutter project structure from the PRD (feature-first folders), add Riverpod and GoRouter, a basic theme, and placeholder screens: Login, Home, Request Ride, My Rides. Create PROGRESS.md. App must run with navigation between screens."

## Step 2: Database
Prompt: "Write one SQL migration file for Supabase with the tables from the PRD data model, enable PostGIS, and add Row Level Security policies so users only see their own data. Do not touch the Flutter code yet."
(You run the SQL in the Supabase SQL editor.)

## Step 3: Authentication
Prompt: "Add Supabase auth to the Flutter app. Use email login for development (phone OTP needs a paid SMS provider; we will switch later). Add a user profile row on signup and a role (rider/driver)."

## Step 4: Map and location picking
Prompt: "Add flutter_map with OpenStreetMap tiles to the Request Ride screen. Let the user pick pickup and drop-off by tapping the map and by searching with Barikoi. Wrap geocoding behind an abstract service interface. Use a free-tier tile provider, keep the API keys in a config file excluded from git."

## Step 5: Create a ride request
Prompt: "Let the rider choose a departure time and time flexibility, then save a ride_request to Supabase. Show 'My Rides' with status. No matching yet."

## Step 6: Fare calculation
Prompt: "Use OpenRouteService to get route distance and duration. Implement the fare calculator from the PRD (solo fare, shared fare, platform fee). Put the pricing numbers in a config table. Write unit tests. Show estimated solo vs shared price on the request screen."

## Step 7: Matching engine (core feature)
Prompt: "Implement matching as a Supabase SQL function (PostGIS) or Edge Function following the PRD compatibility rules: overlapping time windows, pickup within 1.5 km, drop-off within 2 km, groups of 2-4. Create ride_groups and group_members. Write tests with sample data. Add a script that inserts 10 fake requests so I can test it."

## Step 8: Rider group status screen
Prompt: "Use Supabase Realtime so the rider sees status changes: Finding riders, Group found (co-rider count, final fare, pickup time), Driver assigned. Add the cancel flow."

## Step 9: Driver mode
Prompt: "Add driver role screens: go online/offline, see an assigned group, accept/decline, ordered pickup and drop-off stops on the map, buttons to mark picked up and dropped. For now assign drivers manually from the database."

## Step 10: Live tracking
Prompt: "Driver app sends its GPS location to Supabase every few seconds while on a trip. The rider sees the driver's marker moving on the map with ETA."

## Step 11: Push notifications
Prompt: "Add Firebase Cloud Messaging for: group found, driver assigned, driver arriving, trip completed."

## Step 12: Payments
Prompt: "Add cash payment recording first (driver confirms cash). Then add the bKash/Nagad sandbox integration through the chosen aggregator, in a separate step if quota is low."

## Step 13: Ratings, safety, admin
Prompt: "Add ratings after trip, an SOS button, and a simple admin web page (React) for viewing requests, groups, and approving drivers."

## Step 14: Automatic driver assignment, polish, beta
- Auto-assign nearest driver.
- Bangla/English translations.
- Fix bugs, test with 10-20 real users on one route.

## Recommended order if quota is very limited
Do Steps 1, 2, 3, 4, 5, 7 first. That proves the core idea (requests matched into groups). Everything else can wait until the idea is validated with real people.

## Tips to save quota
- Give small, specific prompts. Say which file to change.
- Don't paste whole files back unless needed; paste only the error and the related code.
- Ask for a short answer: "Only change the necessary files and don't explain."
- Do planning and learning questions in a free chat (like this one), and use Antigravity mainly for code edits.
