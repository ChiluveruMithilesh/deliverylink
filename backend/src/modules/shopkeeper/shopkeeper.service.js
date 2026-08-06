'use strict';

const { query } = require('../../config/database');
const ApiError = require('../../utils/ApiError');

async function listMyShops(userId) {
  const { rows } = await query(
    'SELECT * FROM shops WHERE shopkeeper_user_id = $1 ORDER BY created_at DESC',
    [userId]
  );
  return rows;
}

async function addShop(userId, payload) {
  const { rows } = await query(
    `INSERT INTO shops (shopkeeper_user_id, shop_name, contact_number, address, lat, lng)
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
    [userId, payload.shopName, payload.contactNumber, payload.address, payload.lat, payload.lng]
  );
  return rows[0];
}

async function updateShop(userId, shopId, payload) {
  const { rows: existing } = await query('SELECT id FROM shops WHERE id = $1 AND shopkeeper_user_id = $2', [
    shopId,
    userId,
  ]);
  if (!existing[0]) throw ApiError.notFound('Shop not found');

  const mapping = { shopName: 'shop_name', contactNumber: 'contact_number', address: 'address', lat: 'lat', lng: 'lng' };
  const fields = [];
  const values = [];
  let idx = 1;
  for (const [key, column] of Object.entries(mapping)) {
    if (payload[key] !== undefined) {
      fields.push(`${column} = $${idx++}`);
      values.push(payload[key]);
    }
  }
  if (fields.length === 0) return getShop(userId, shopId);

  values.push(shopId);
  const { rows } = await query(`UPDATE shops SET ${fields.join(', ')} WHERE id = $${idx} RETURNING *`, values);
  return rows[0];
}

async function getShop(userId, shopId) {
  const { rows } = await query('SELECT * FROM shops WHERE id = $1 AND shopkeeper_user_id = $2', [
    shopId,
    userId,
  ]);
  if (!rows[0]) throw ApiError.notFound('Shop not found');
  return rows[0];
}

/**
 * Deliveries scheduled for today across all of this shopkeeper's shops,
 * with driver + distributor info and live status.
 */
async function getTodaysDeliveries(userId) {
  const { rows } = await query(
    `SELECT ts.id AS stop_id, ts.status, ts.quantity, ts.unit_type, ts.sequence_number,
            t.id AS trip_id, t.status AS trip_status, t.estimated_duration_min,
            dist.business_name AS distributor_name,
            du.full_name AS driver_name, dr.vehicle_number, dr.current_lat, dr.current_lng
     FROM trip_stops ts
     JOIN shops s ON s.id = ts.shop_id
     JOIN trips t ON t.id = ts.trip_id
     JOIN distributors dist ON dist.id = t.distributor_id
     LEFT JOIN drivers dr ON dr.id = t.driver_id
     LEFT JOIN users du ON du.id = dr.user_id
     WHERE s.shopkeeper_user_id = $1
       AND t.created_at::date = CURRENT_DATE
       AND t.status NOT IN ('cancelled', 'draft')
     ORDER BY t.created_at DESC`,
    [userId]
  );
  return rows;
}

async function getDeliveryHistory(userId, { page = 1, limit = 20 } = {}) {
  const offset = (page - 1) * limit;
  const { rows } = await query(
    `SELECT ts.id AS stop_id, ts.status, ts.delivered_at, ts.quantity, ts.unit_type,
            t.id AS trip_id, dist.business_name AS distributor_name,
            dp.photo_url, dp.captured_at
     FROM trip_stops ts
     JOIN shops s ON s.id = ts.shop_id
     JOIN trips t ON t.id = ts.trip_id
     JOIN distributors dist ON dist.id = t.distributor_id
     LEFT JOIN delivery_proofs dp ON dp.trip_stop_id = ts.id
     WHERE s.shopkeeper_user_id = $1 AND ts.status = 'delivered'
     ORDER BY ts.delivered_at DESC LIMIT $2 OFFSET $3`,
    [userId, limit, offset]
  );
  return rows;
}

module.exports = { listMyShops, addShop, updateShop, getShop, getTodaysDeliveries, getDeliveryHistory };
