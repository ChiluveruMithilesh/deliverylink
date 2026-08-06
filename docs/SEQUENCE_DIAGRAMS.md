# Sequence Diagrams

## 1. Full delivery lifecycle

```mermaid
sequenceDiagram
    participant D as Distributor App
    participant API as Backend API
    participant DB as PostgreSQL
    participant Drv as Driver App
    participant Shop as Shopkeeper App
    participant FCM as Firebase (Push)

    D->>API: POST /trips (pickup, goods, 1-40 stops)
    API->>API: optimizeRoute() [Google Directions or haversine fallback]
    API->>DB: INSERT trip + trip_stops (status=draft)
    API-->>D: 201 trip

    D->>API: POST /trips/:id/publish
    API->>DB: UPDATE trip SET status=published
    API->>DB: SELECT online drivers within 20km
    API->>FCM: notify nearby drivers
    FCM-->>Drv: push "New trip nearby"

    Drv->>API: GET /trips/nearby?lat&lng
    API-->>Drv: ranked list by distance

    Drv->>API: POST /trips/:id/bids {offeredAmount}
    API->>DB: UPSERT trip_bids
    API->>FCM: notify distributor "New bid"

    D->>API: GET /trips/:id/bids
    D->>API: POST /trips/:id/bids/:bidId/select
    API->>DB: UPDATE trip SET status=assigned, driver_id=...
    API->>FCM: notify driver "Assigned"
    API->>DB: SELECT shops in this trip
    API->>FCM: notify each shopkeeper "Delivery scheduled"

    Drv->>API: POST /trips/:id/confirm-pickup
    API->>DB: UPDATE trip SET status=in_progress
    API->>FCM: notify distributor "Driver started"

    loop every ~10-30s while in progress
        Drv->>API: POST /trips/:id/location {lat,lng}
        API->>DB: INSERT location_history
        API->>API: cache latest point in Redis (TTL 120s)
    end

    Shop->>API: GET /trips/:id/track
    API-->>Shop: current location + stop statuses

    Drv->>API: POST /trips/:id/stops/:stopId/arrive
    API->>FCM: notify shopkeeper "Driver approaching"

    Drv->>API: POST /trips/:id/stops/:stopId/deliver {photoUrl, gps, otp?}
    API->>DB: INSERT delivery_proofs, UPDATE stop status=delivered
    API->>FCM: notify shopkeeper "Delivered"
    API->>DB: check remaining stops

    alt all stops delivered
        API->>DB: UPDATE trip SET status=completed
        API->>DB: increment driver.total_trips, distributor.total_trips
        API->>FCM: notify distributor "Trip completed"
    end
```

## 2. Authentication + token refresh

```mermaid
sequenceDiagram
    participant App as Flutter App
    participant API as Backend API
    participant DB as PostgreSQL

    App->>API: POST /auth/register {role, phone, password, ...}
    API->>DB: check phone uniqueness
    API->>DB: BEGIN; INSERT user; INSERT role profile; COMMIT
    API-->>App: {user, accessToken, refreshToken}
    App->>App: save tokens to SecureStorage

    Note over App,API: Later - access token expired
    App->>API: GET /trips (Authorization: Bearer <expired>)
    API-->>App: 401 Unauthorized
    App->>API: POST /auth/refresh {refreshToken}
    API->>API: verify refresh token
    API-->>App: {accessToken, refreshToken}
    App->>API: retry GET /trips (Authorization: Bearer <new>)
    API-->>App: 200 OK
```

## 3. Driver document verification (Admin)

```mermaid
sequenceDiagram
    participant Drv as Driver App
    participant API as Backend API
    participant Adm as Admin Panel
    participant FCM as Firebase (Push)

    Drv->>API: PATCH /driver/profile {drivingLicencePhotoUrl, ...}
    API->>API: verification_status reset to 'pending'
    Adm->>API: GET /admin/drivers/pending
    API-->>Adm: list of pending drivers
    Adm->>API: PATCH /admin/drivers/:id/review {decision: approved}
    API->>FCM: notify driver "Verification approved"
    FCM-->>Drv: push notification
    Note over Drv: Driver can now accept trips
```
