# Entity-Relationship Diagram

Rendered from `backend/src/db/migrations/001_init_schema.sql` and `002_device_tokens.sql`.

```mermaid
erDiagram
    USERS ||--o| DISTRIBUTORS : "has profile"
    USERS ||--o| DRIVERS : "has profile"
    USERS ||--o{ SHOPS : "owns"
    USERS ||--o{ DEVICE_TOKENS : "registers"
    USERS ||--o{ NOTIFICATIONS : "receives"
    USERS ||--o{ AUDIT_LOGS : "generates"

    DISTRIBUTORS ||--o{ TRIPS : "creates"
    DRIVERS ||--o{ TRIPS : "assigned to"
    DRIVERS ||--o{ TRIP_BIDS : "places"
    DRIVERS ||--o{ LOCATION_HISTORY : "logs"

    TRIPS ||--|{ TRIP_STOPS : "contains 1-40"
    TRIPS ||--o{ TRIP_BIDS : "receives"
    TRIPS ||--o{ LOCATION_HISTORY : "tracked by"
    TRIPS ||--o{ NOTIFICATIONS : "triggers"

    TRIP_STOPS ||--o| DELIVERY_PROOFS : "proven by"
    SHOPS ||--o{ TRIP_STOPS : "is destination for"

    USERS {
        uuid id PK
        enum role
        string full_name
        string phone UK
        string password_hash
        string preferred_language
        boolean is_active
    }

    DISTRIBUTORS {
        uuid id PK
        uuid user_id FK
        string business_name
        numeric rating
        int total_trips
    }

    DRIVERS {
        uuid id PK
        uuid user_id FK
        string driving_licence_number
        enum vehicle_type
        string vehicle_number UK
        numeric vehicle_capacity_kg
        enum verification_status
        double current_lat
        double current_lng
        boolean is_online
        numeric rating
    }

    SHOPS {
        uuid id PK
        uuid shopkeeper_user_id FK
        string shop_name
        string contact_number
        double lat
        double lng
    }

    TRIPS {
        uuid id PK
        uuid distributor_id FK
        uuid driver_id FK
        double pickup_lat
        double pickup_lng
        text goods_description
        numeric goods_value
        numeric payment_offered
        enum status
        int total_stops
        jsonb optimized_route
    }

    TRIP_STOPS {
        uuid id PK
        uuid trip_id FK
        uuid shop_id FK
        int sequence_number
        string shop_name
        int quantity
        enum unit_type
        enum status
        string delivery_otp
    }

    DELIVERY_PROOFS {
        uuid id PK
        uuid trip_stop_id FK
        text photo_url
        double captured_lat
        double captured_lng
        timestamptz captured_at
    }

    TRIP_BIDS {
        uuid id PK
        uuid trip_id FK
        uuid driver_id FK
        numeric offered_amount
        enum status
    }

    LOCATION_HISTORY {
        bigint id PK
        uuid trip_id FK
        uuid driver_id FK
        double lat
        double lng
        timestamptz recorded_at
    }

    NOTIFICATIONS {
        uuid id PK
        uuid user_id FK
        uuid trip_id FK
        string title
        text body
        enum status
    }

    DEVICE_TOKENS {
        uuid id PK
        uuid user_id FK
        text fcm_token
        string platform
    }

    AUDIT_LOGS {
        bigint id PK
        uuid user_id FK
        string action
        string entity_type
        uuid entity_id
    }

    PRICING_RULES {
        uuid id PK
        string name
        numeric min_distance_km
        numeric max_distance_km
        numeric base_fare
        numeric per_km_rate
    }
```

## Notes

- `trips.total_stops` is a denormalized count (1–40, enforced by a CHECK constraint) kept in sync with `trip_stops` rows for fast list-view rendering without a `COUNT()` join.
- `trip_stops.delivery_otp` is generated at trip-creation time and verified (optionally) at the delivery step — this is the "OTP" proof-of-delivery option alongside photo + GPS.
- `location_history` is append-only and unbounded; in production, add a scheduled job to archive rows older than N days to cold storage, since this table grows fastest.
- All foreign keys use `ON DELETE CASCADE` for owned child records (e.g. `trip_stops` under `trips`) and `ON DELETE SET NULL` where the parent's removal shouldn't destroy history (e.g. `trips.driver_id`).
