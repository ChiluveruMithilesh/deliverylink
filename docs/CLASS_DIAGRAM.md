# Class / Module Diagram

Backend modules follow a consistent shape. This diagram shows the trips module (the largest) as the representative example — every other module (`auth`, `driver`, `distributor`, `shopkeeper`, `admin`, `notifications`) follows the same routes → controller → service → database pattern.

```mermaid
classDiagram
    class TripsRoutes {
        +POST /trips
        +GET /trips
        +GET /trips/nearby
        +PUT /trips/:id
        +POST /trips/:id/publish
        +POST /trips/:id/cancel
        +POST /trips/:id/bids
        +GET /trips/:id/bids
        +POST /trips/:id/bids/:bidId/select
        +POST /trips/:id/confirm-pickup
        +POST /trips/:id/location
        +GET /trips/:id/track
        +POST /trips/:id/stops/:stopId/arrive
        +POST /trips/:id/stops/:stopId/deliver
    }

    class TripsController {
        +createHandler(req, res)
        +publishHandler(req, res)
        +placeBidHandler(req, res)
        +selectBidHandler(req, res)
        +deliverHandler(req, res)
        ...
    }

    class TripsService {
        +createTrip(userId, payload)
        +updateTrip(userId, tripId, payload)
        +publishTrip(userId, tripId)
        +placeBid(userId, tripId, amount)
        +selectBid(userId, tripId, bidId)
        +confirmPickup(userId, tripId)
        +recordLocationPing(userId, tripId, lat, lng)
        +getLiveTracking(user, tripId)
        +arriveAtStop(userId, tripId, stopId)
        +deliverStop(userId, tripId, stopId, proof)
    }

    class GoogleMapsUtil {
        +getOptimizedRoute(originLat, originLng, stops)
        +haversineDistanceKm(lat1, lng1, lat2, lng2)
        +optimizeStopOrder(originLat, originLng, stops)
    }

    class NotificationsService {
        +notifyUser(userId, title, body)
        +registerDeviceToken(userId, token, platform)
    }

    class Database {
        +query(text, params)
        +withTransaction(callback)
    }

    class AuthMiddleware {
        +authenticate(req, res, next)
        +authorize(...roles)
    }

    TripsRoutes --> AuthMiddleware : uses
    TripsRoutes --> TripsController : delegates to
    TripsController --> TripsService : calls
    TripsService --> GoogleMapsUtil : uses for routing
    TripsService --> NotificationsService : triggers on state change
    TripsService --> Database : reads/writes
```

## Flutter presentation-layer pattern

```mermaid
classDiagram
    class Screen {
        <<Widget>>
        build(context, ref)
    }

    class RiverpodProvider {
        <<FutureProvider or StateNotifier>>
    }

    class Repository {
        +createTrip(payload)
        +listTrips(status)
        +placeBid(tripId, amount)
    }

    class ApiClient {
        +get(path)
        +post(path, data)
        +put(path, data)
        +patch(path, data)
    }

    class SecureStorage {
        +getAccessToken()
        +saveTokens(access, refresh)
    }

    Screen --> RiverpodProvider : watches
    RiverpodProvider --> Repository : calls
    Repository --> ApiClient : calls
    ApiClient --> SecureStorage : reads token for Authorization header
```
