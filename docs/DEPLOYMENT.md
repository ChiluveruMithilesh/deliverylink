# Deployment Guide

## Local development

```bash
cd backend
cp .env.example .env    # set DB_PASSWORD, JWT_ACCESS_SECRET, JWT_REFRESH_SECRET at minimum
cd ../docker
docker compose up -d
docker compose exec backend npm run migrate
```

Verify:
```bash
curl http://localhost:4000/health   # {"success":true,"status":"ok",...}
curl http://localhost:4000/ready    # confirms DB connectivity
```

Swagger UI: `http://localhost:4000/api/docs`

## Production deployment (Docker Compose + NGINX)

1. **Provision a host** (VM with Docker + Docker Compose installed; 2 vCPU / 4GB RAM minimum for light load).

2. **Create `backend/.env.production`** with real secrets:
   ```
   NODE_ENV=production
   DB_NAME=deliverylink
   DB_USER=deliverylink_app
   DB_PASSWORD=<strong random password>
   REDIS_PASSWORD=<strong random password>
   JWT_ACCESS_SECRET=<32+ char random string>
   JWT_REFRESH_SECRET=<different 32+ char random string>
   FIREBASE_PROJECT_ID=...
   FIREBASE_CLIENT_EMAIL=...
   FIREBASE_PRIVATE_KEY=...
   GOOGLE_DIRECTIONS_API_KEY=...
   GOOGLE_DISTANCE_MATRIX_API_KEY=...
   ```
   Never commit this file. Store secrets in your CI/CD provider's secret manager or a vault.

3. **Provision TLS certificates** (e.g. via `certbot`) and place them at `docker/nginx/certs/fullchain.pem` and `privkey.pem`. Uncomment the HTTPS `server` block in `docker/nginx/nginx.conf`.

4. **Deploy:**
   ```bash
   cd docker
   docker compose -f docker-compose.prod.yml up -d --build
   docker compose -f docker-compose.prod.yml exec backend npm run migrate
   ```

5. **Point your domain's DNS** at the host's IP.

### Scaling notes

- The `backend` service is stateless (JWT auth, no in-memory session) — increase `deploy.replicas` in `docker-compose.prod.yml` and NGINX will load-balance across them automatically via Docker's embedded DNS round-robin.
- `location_history` is the highest-write-volume table (one row per GPS ping per active trip). Consider partitioning by month or moving to a time-series store (TimescaleDB extension for Postgres, already PostGIS-based) if trip volume grows significantly.
- Redis is used for the live-tracking cache and rate limiting; a single instance is fine until you need HA, at which point move to Redis Sentinel or a managed Redis service.
- Move file uploads from local disk (`backend/tmp/uploads`, mounted as a Docker volume) to Firebase Storage or S3 + CDN once you need multi-region reads.

## CI/CD

`.github/workflows/backend-ci.yml` runs on every push/PR touching `backend/`:
1. Lint (`eslint`)
2. Spin up ephemeral Postgres + Redis service containers
3. Run migrations against the test database
4. Run the full Jest suite with coverage
5. On `main`: build and push a Docker image to GitHub Container Registry
6. Deploy step is a template — wire it to your actual infrastructure (SSH + `docker compose pull && up -d`, a Kubernetes rollout, or a managed platform's deploy webhook)

## Flutter app builds

```bash
cd flutter_app
flutter create .   # first time only, generates android/ and ios/

# Android release APK
flutter build apk --release --dart-define=API_BASE_URL=https://api.yourdomain.com/api/v1

# iOS release (requires macOS + Xcode)
flutter build ios --release --dart-define=API_BASE_URL=https://api.yourdomain.com/api/v1

# Web
flutter build web --release --dart-define=API_BASE_URL=https://api.yourdomain.com/api/v1
```

Before building, add Firebase config files (`google-services.json`, `GoogleService-Info.plist`) and a Google Maps API key to the platform manifests, per the [Firebase Flutter setup docs](https://firebase.google.com/docs/flutter/setup) and [google_maps_flutter setup docs](https://pub.dev/packages/google_maps_flutter).

## Database migrations in production

Migrations are tracked in a `schema_migrations` table (see `backend/src/db/migrate.js`) — each file in `backend/src/db/migrations/` runs exactly once, in filename order, inside its own transaction. To add a new migration, create `backend/src/db/migrations/00X_description.sql` and run `npm run migrate` — never edit an already-applied migration file.
