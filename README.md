# DeliveryLink

A marketplace platform connecting FMCG distributors with local auto drivers to deliver goods to multiple retail shops — like Uber/Rapido, but for goods instead of people.

## Who uses it

| Role | What they do |
|---|---|
| **Distributor** | Creates delivery trips with 1–40 shop stops, sets a payment offer, compares driver bids, tracks delivery live |
| **Auto Driver** | Browses nearby trips, accepts or counter-offers, navigates multi-stop routes, uploads photo proof of delivery |
| **Shopkeeper** | Gets notified when a delivery is scheduled, tracks the vehicle live until it arrives |
| **Admin** | Verifies driver documents, manages users, monitors trips, sets pricing rules |

## Tech stack

- **Backend:** Node.js, Express, PostgreSQL (PostGIS), Redis, JWT auth, Firebase (push notifications), Google Maps Platform (route optimization)
- **Frontend:** Flutter (Android/iOS/Web), Material 3, Riverpod, GoRouter, Dio, Hive (offline cache)
- **Infra:** Docker Compose, NGINX, GitHub Actions

## Repository structure

```
deliverylink/
├── backend/              Node.js/Express API
│   └── src/
│       ├── config/       env, database, redis, firebase, swagger
│       ├── middleware/   auth, error handling, rate limiting, validation
│       ├── modules/      auth, trips, driver, distributor, shopkeeper, admin, notifications, uploads
│       ├── db/           migrations, migration runner
│       └── utils/        logger, ApiError, JWT, Google Maps helper
│   └── tests/            unit + integration (Jest + Supertest)
├── flutter_app/          Flutter client (Clean Architecture, feature-first)
│   └── lib/
│       ├── core/         theme, router, network client, storage, providers
│       ├── features/     auth, distributor, driver, shopkeeper (each: models, data, presentation)
│       └── shared/       reusable widgets
├── docker/                docker-compose (dev + prod), NGINX config
├── docs/                  architecture, ER diagram, sequence diagrams, deployment guide
└── .github/workflows/     CI/CD pipeline
```

## Quick start (backend)

```bash
cd backend
cp .env.example .env        # fill in DB_PASSWORD, JWT secrets at minimum
cd ../docker
docker compose up -d
docker compose exec backend npm run migrate
curl http://localhost:4000/health
```

API docs (Swagger UI): `http://localhost:4000/api/docs`

Run tests:
```bash
cd backend
npm test
```

## Quick start (Flutter app)

```bash
cd flutter_app
flutter create .             # generates android/ and ios/ platform folders
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1
```

`10.0.2.2` is the Android emulator's alias for your host machine's `localhost`. On iOS simulator or a physical device, use your machine's LAN IP instead.

Before running on a real device, add:
- `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist` (Firebase)
- A Google Maps API key in `android/app/src/main/AndroidManifest.xml` and `ios/Runner/AppDelegate.swift`

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), [`docs/ER_DIAGRAM.md`](docs/ER_DIAGRAM.md), and [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) for more.
