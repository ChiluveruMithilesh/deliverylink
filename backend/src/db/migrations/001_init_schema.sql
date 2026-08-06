-- =========================================================
-- DeliveryLink - Initial Schema Migration
-- PostgreSQL 15+
-- =========================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "postgis"; -- for geography/GPS columns

-- =========================================================
-- ENUM TYPES
-- =========================================================
CREATE TYPE user_role AS ENUM ('distributor', 'driver', 'shopkeeper', 'admin');
CREATE TYPE verification_status AS ENUM ('pending', 'approved', 'rejected', 'suspended');
CREATE TYPE vehicle_type AS ENUM ('auto', 'mini_truck', 'pickup', 'tempo');
CREATE TYPE unit_type AS ENUM ('cartons', 'bags', 'boxes');
CREATE TYPE trip_status AS ENUM (
  'draft', 'published', 'assigned', 'pickup_confirmed',
  'in_progress', 'completed', 'cancelled'
);
CREATE TYPE stop_status AS ENUM ('pending', 'en_route', 'arrived', 'delivered', 'failed', 'skipped');
CREATE TYPE bid_status AS ENUM ('offered', 'countered', 'accepted', 'rejected', 'withdrawn');
CREATE TYPE notification_channel AS ENUM ('push', 'sms', 'in_app');
CREATE TYPE notification_status AS ENUM ('queued', 'sent', 'failed', 'read');

-- =========================================================
-- USERS (base identity table for all roles)
-- =========================================================
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  role user_role NOT NULL,
  full_name VARCHAR(120) NOT NULL,
  phone VARCHAR(15) NOT NULL UNIQUE,
  email VARCHAR(160) UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  firebase_uid VARCHAR(128) UNIQUE,
  preferred_language VARCHAR(5) NOT NULL DEFAULT 'en',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  is_phone_verified BOOLEAN NOT NULL DEFAULT FALSE,
  last_login_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_phone ON users(phone);

-- =========================================================
-- DISTRIBUTORS
-- =========================================================
CREATE TABLE distributors (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  business_name VARCHAR(150) NOT NULL,
  gstin VARCHAR(20),
  default_pickup_lat DOUBLE PRECISION,
  default_pickup_lng DOUBLE PRECISION,
  default_pickup_address TEXT,
  rating NUMERIC(2,1) NOT NULL DEFAULT 5.0 CHECK (rating >= 0 AND rating <= 5),
  total_trips INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================================================
-- DRIVERS
-- =========================================================
CREATE TABLE drivers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  driving_licence_number VARCHAR(40) NOT NULL,
  driving_licence_photo_url TEXT,
  aadhaar_number VARCHAR(20),
  vehicle_type vehicle_type NOT NULL,
  vehicle_number VARCHAR(20) NOT NULL UNIQUE,
  vehicle_capacity_kg NUMERIC(8,2) NOT NULL,
  vehicle_rc_photo_url TEXT,
  insurance_photo_url TEXT,
  profile_photo_url TEXT,
  verification_status verification_status NOT NULL DEFAULT 'pending',
  current_lat DOUBLE PRECISION,
  current_lng DOUBLE PRECISION,
  current_location_updated_at TIMESTAMPTZ,
  is_online BOOLEAN NOT NULL DEFAULT FALSE,
  rating NUMERIC(2,1) NOT NULL DEFAULT 5.0 CHECK (rating >= 0 AND rating <= 5),
  total_trips INTEGER NOT NULL DEFAULT 0,
  total_distance_km NUMERIC(10,2) NOT NULL DEFAULT 0,
  acceptance_rate NUMERIC(5,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_drivers_online_location ON drivers(is_online, current_lat, current_lng);
CREATE INDEX idx_drivers_verification ON drivers(verification_status);

-- =========================================================
-- SHOPS (owned/managed by shopkeepers)
-- =========================================================
CREATE TABLE shops (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  shopkeeper_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  shop_name VARCHAR(150) NOT NULL,
  contact_number VARCHAR(15) NOT NULL,
  address TEXT NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_shops_shopkeeper ON shops(shopkeeper_user_id);
CREATE INDEX idx_shops_location ON shops(lat, lng);

-- =========================================================
-- TRIPS
-- =========================================================
CREATE TABLE trips (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  distributor_id UUID NOT NULL REFERENCES distributors(id) ON DELETE CASCADE,
  driver_id UUID REFERENCES drivers(id) ON DELETE SET NULL,
  pickup_address TEXT NOT NULL,
  pickup_lat DOUBLE PRECISION NOT NULL,
  pickup_lng DOUBLE PRECISION NOT NULL,
  goods_description TEXT NOT NULL,
  total_quantity INTEGER NOT NULL CHECK (total_quantity > 0),
  goods_value NUMERIC(12,2) NOT NULL CHECK (goods_value >= 0),
  payment_offered NUMERIC(10,2) NOT NULL CHECK (payment_offered >= 0),
  status trip_status NOT NULL DEFAULT 'draft',
  total_stops INTEGER NOT NULL CHECK (total_stops BETWEEN 1 AND 40),
  optimized_route JSONB,
  estimated_distance_km NUMERIC(8,2),
  estimated_duration_min INTEGER,
  published_at TIMESTAMPTZ,
  assigned_at TIMESTAMPTZ,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  cancellation_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_trips_distributor ON trips(distributor_id);
CREATE INDEX idx_trips_driver ON trips(driver_id);
CREATE INDEX idx_trips_status ON trips(status);
CREATE INDEX idx_trips_pickup_location ON trips(pickup_lat, pickup_lng);
CREATE INDEX idx_trips_created_at ON trips(created_at DESC);

-- =========================================================
-- TRIP STOPS (1-40 per trip)
-- =========================================================
CREATE TABLE trip_stops (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  shop_id UUID REFERENCES shops(id) ON DELETE SET NULL,
  sequence_number INTEGER NOT NULL,
  shop_name VARCHAR(150) NOT NULL,
  contact_number VARCHAR(15) NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unit_type unit_type NOT NULL,
  notes TEXT,
  status stop_status NOT NULL DEFAULT 'pending',
  arrived_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  delivery_otp VARCHAR(6),
  UNIQUE (trip_id, sequence_number)
);

CREATE INDEX idx_trip_stops_trip ON trip_stops(trip_id);
CREATE INDEX idx_trip_stops_shop ON trip_stops(shop_id);
CREATE INDEX idx_trip_stops_status ON trip_stops(status);

-- =========================================================
-- DELIVERY PROOF (photo + gps + timestamp per stop)
-- =========================================================
CREATE TABLE delivery_proofs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_stop_id UUID NOT NULL UNIQUE REFERENCES trip_stops(id) ON DELETE CASCADE,
  photo_url TEXT NOT NULL,
  captured_lat DOUBLE PRECISION NOT NULL,
  captured_lng DOUBLE PRECISION NOT NULL,
  signature_url TEXT,
  captured_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================================================
-- TRIP BIDS (driver accept / counter-offer)
-- =========================================================
CREATE TABLE trip_bids (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
  offered_amount NUMERIC(10,2) NOT NULL,
  status bid_status NOT NULL DEFAULT 'offered',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (trip_id, driver_id)
);

CREATE INDEX idx_trip_bids_trip ON trip_bids(trip_id);
CREATE INDEX idx_trip_bids_driver ON trip_bids(driver_id);

-- =========================================================
-- LOCATION HISTORY (live GPS trail per trip)
-- =========================================================
CREATE TABLE location_history (
  id BIGSERIAL PRIMARY KEY,
  trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_location_history_trip ON location_history(trip_id, recorded_at DESC);

-- =========================================================
-- NOTIFICATIONS
-- =========================================================
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  trip_id UUID REFERENCES trips(id) ON DELETE SET NULL,
  title VARCHAR(150) NOT NULL,
  body TEXT NOT NULL,
  channel notification_channel NOT NULL DEFAULT 'push',
  status notification_status NOT NULL DEFAULT 'queued',
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_notifications_user ON notifications(user_id, created_at DESC);
CREATE INDEX idx_notifications_status ON notifications(status);

-- =========================================================
-- AUDIT LOGS (security requirement)
-- =========================================================
CREATE TABLE audit_logs (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  action VARCHAR(100) NOT NULL,
  entity_type VARCHAR(50),
  entity_id UUID,
  ip_address VARCHAR(45),
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);

-- =========================================================
-- ADMIN / PRICING RULES
-- =========================================================
CREATE TABLE pricing_rules (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(100) NOT NULL,
  min_distance_km NUMERIC(6,2) NOT NULL,
  max_distance_km NUMERIC(6,2) NOT NULL,
  base_fare NUMERIC(10,2) NOT NULL,
  per_km_rate NUMERIC(10,2) NOT NULL,
  per_stop_rate NUMERIC(10,2) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================================================
-- updated_at auto-touch trigger
-- =========================================================
CREATE OR REPLACE FUNCTION touch_updated_at() RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_distributors_updated_at BEFORE UPDATE ON distributors
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_drivers_updated_at BEFORE UPDATE ON drivers
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_trips_updated_at BEFORE UPDATE ON trips
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_trip_bids_updated_at BEFORE UPDATE ON trip_bids
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
