-- =========================================================
-- DeliveryLink - User Codes + Order Requests
-- =========================================================

-- Short, human-shareable identifier for every user (e.g. "DL-7K2M9X").
-- Used so a shopkeeper can unambiguously address a specific distributor
-- (and vice versa in future) without relying on names, which may collide.
ALTER TABLE users ADD COLUMN user_code VARCHAR(12) UNIQUE;

CREATE INDEX idx_users_user_code ON users(user_code);

-- =========================================================
-- ORDER REQUESTS
-- A shopkeeper requests goods from a specific distributor by their
-- user_code. This is a structured request-with-status, not a free-form
-- chat thread, so distributors get an organized inbox of "who wants what."
-- =========================================================
CREATE TYPE order_request_status AS ENUM ('pending', 'acknowledged', 'fulfilled', 'declined');

CREATE TABLE order_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  shopkeeper_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  distributor_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  status order_request_status NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_order_requests_shopkeeper ON order_requests(shopkeeper_user_id, created_at DESC);
CREATE INDEX idx_order_requests_distributor ON order_requests(distributor_user_id, created_at DESC);
CREATE INDEX idx_order_requests_status ON order_requests(status);

CREATE TRIGGER trg_order_requests_updated_at BEFORE UPDATE ON order_requests
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();