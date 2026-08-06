# Installation Guide

## Prerequisites

- Docker Desktop (or Docker Engine + Docker Compose on Linux)
- Node.js 18+ (only needed if running the backend outside Docker)
- Flutter SDK 3.3+ (for the mobile/web app)
- A Google Cloud project with Directions API, Distance Matrix API, and Maps SDK enabled (optional for local dev — the backend falls back to a haversine-based route estimate without it)
- A Firebase project (optional for local dev — push notifications are skipped gracefully if unconfigured)

## 1. Backend

```bash
git clone <your-repo-url>
cd deliverylink/backend
cp .env.example .env
```

Edit `.env` and set at minimum:
- `DB_PASSWORD`
- `JWT_ACCESS_SECRET` (32+ random characters)
- `JWT_REFRESH_SECRET` (a different 32+ random characters)

Start infrastructure and the API:
```bash
cd ../docker
docker compose up -d
docker compose exec backend npm run migrate
```

Confirm it's running:
```bash
curl http://localhost:4000/health
curl http://localhost:4000/ready
```

Try the auth flow:
```bash
curl -X POST http://localhost:4000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"role":"distributor","fullName":"Test Distributor","phone":"9876543210","password":"testpass123","businessName":"ABC Traders"}'
```

You should receive a JSON response with a `user` object and `accessToken`/`refreshToken`.

### Running the backend without Docker

```bash
cd backend
npm install
# Point DB_HOST/REDIS_HOST in .env at your local Postgres/Redis instances
npm run migrate
npm run dev   # nodemon, auto-restarts on file changes
```

### Running backend tests

```bash
cd backend
npm test              # unit + integration, no live DB required for most tests
npm run lint
```

## 2. Flutter app

```bash
cd flutter_app
flutter create .        # generates android/ and ios/ platform folders (first time only)
flutter pub get
```

### Point the app at your backend

The API base URL is set at build/run time via `--dart-define`:

```bash
# Android emulator (10.0.2.2 = host machine's localhost from inside the emulator)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1

# iOS simulator or physical device (use your machine's LAN IP)
flutter run --dart-define=API_BASE_URL=http://192.168.1.X:4000/api/v1

# Web
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000/api/v1
```

### Add Firebase (for push notifications)

1. Create a Firebase project, add Android/iOS/Web apps to it.
2. Download `google-services.json` into `android/app/`.
3. Download `GoogleService-Info.plist` into `ios/Runner/`.
4. In `lib/main.dart`, uncomment `await Firebase.initializeApp();`.

### Add Google Maps

1. Get an API key from Google Cloud Console with Maps SDK for Android/iOS enabled.
2. Add it to `android/app/src/main/AndroidManifest.xml` inside the `<application>` tag:
   ```xml
   <meta-data android:name="com.google.android.geo.API_KEY" android:value="YOUR_KEY"/>
   ```
3. Add it to `ios/Runner/AppDelegate.swift` per the [google_maps_flutter setup guide](https://pub.dev/packages/google_maps_flutter).

### Running Flutter tests

```bash
flutter test
```

## 3. Verify the full flow end-to-end

1. Register a distributor, a driver, and a shopkeeper via the app (or `curl`, as above).
2. As the distributor, create and publish a trip with at least one stop.
3. As the driver, check `/trips/nearby` — the new trip should appear.
4. Accept the trip, confirm pickup, mark the stop delivered.
5. As the shopkeeper, check `/shopkeeper/deliveries/today` — status should reflect each step.

If any step fails, check `backend logs` (`docker compose logs -f backend`) and the response body — every error follows the `{ success: false, error: { message, details } }` shape.
