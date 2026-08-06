'use strict';

const { query } = require('../../config/database');
const ApiError = require('../../utils/ApiError');
const notificationsService = require('../notifications/notifications.service');

async function listUsers({ role, page = 1, limit = 20, search } = {}) {
  const conditions = [];
  const values = [];
  let idx = 1;
  if (role) {
    conditions.push(`role = $${idx++}`);
    values.push(role);
  }
  if (search) {
    conditions.push(`(full_name ILIKE $${idx} OR phone ILIKE $${idx})`);
    values.push(`%${search}%`);
    idx++;
  }
  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  const offset = (page - 1) * limit;
  values.push(limit, offset);

  const { rows } = await query(
    `SELECT id, role, full_name, phone, email, is_active, is_phone_verified, created_at
     FROM users ${where} ORDER BY created_at DESC LIMIT $${idx} OFFSET $${idx + 1}`,
    values
  );
  return rows;
}

async function setUserActive(userId, isActive) {
  const { rows } = await query(
    'UPDATE users SET is_active = $1 WHERE id = $2 RETURNING id, role, is_active',
    [isActive, userId]
  );
  if (!rows[0]) throw ApiError.notFound('User not found');
  return rows[0];
}

async function listPendingDrivers() {
  const { rows } = await query(
    `SELECT d.*, u.full_name, u.phone FROM drivers d
     JOIN users u ON u.id = d.user_id
     WHERE d.verification_status = 'pending'
     ORDER BY d.created_at ASC`
  );
  return rows;
}

async function reviewDriver(driverId, decision) {
  if (!['approved', 'rejected'].includes(decision)) {
    throw ApiError.badRequest('decision must be approved or rejected');
  }
  const { rows } = await query(
    'UPDATE drivers SET verification_status = $1 WHERE id = $2 RETURNING *',
    [decision, driverId]
  );
  const driver = rows[0];
  if (!driver) throw ApiError.notFound('Driver not found');

  await notificationsService.notifyUser({
    userId: driver.user_id,
    title: decision === 'approved' ? 'Verification approved' : 'Verification rejected',
    body:
      decision === 'approved'
        ? 'Your driver documents have been verified. You can now accept trips.'
        : 'Your driver documents were rejected. Please re-upload valid documents.',
  });

  return driver;
}

async function listAllTrips({ status, page = 1, limit = 20 } = {}) {
  const conditions = [];
  const values = [];
  let idx = 1;
  if (status) {
    conditions.push(`t.status = $${idx++}`);
    values.push(status);
  }
  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  const offset = (page - 1) * limit;
  values.push(limit, offset);

  const { rows } = await query(
    `SELECT t.*, dist.business_name AS distributor_name, du.full_name AS driver_name
     FROM trips t
     JOIN distributors dist ON dist.id = t.distributor_id
     LEFT JOIN drivers dr ON dr.id = t.driver_id
     LEFT JOIN users du ON du.id = dr.user_id
     ${where}
     ORDER BY t.created_at DESC LIMIT $${idx} OFFSET $${idx + 1}`,
    values
  );
  return rows;
}

async function getPlatformAnalytics() {
  const { rows: userCounts } = await query(
    `SELECT role, COUNT(*)::int AS count FROM users GROUP BY role`
  );
  const { rows: tripCounts } = await query(
    `SELECT status, COUNT(*)::int AS count FROM trips GROUP BY status`
  );
  const { rows: volume } = await query(
    `SELECT COUNT(*)::int AS trips_last_30_days,
            COALESCE(SUM(payment_offered), 0) AS gmv_last_30_days
     FROM trips WHERE created_at >= now() - interval '30 days'`
  );

  return {
    usersByRole: userCounts.reduce((acc, r) => ({ ...acc, [r.role]: r.count }), {}),
    tripsByStatus: tripCounts.reduce((acc, r) => ({ ...acc, [r.status]: r.count }), {}),
    last30Days: volume[0],
  };
}

async function listPricingRules() {
  const { rows } = await query('SELECT * FROM pricing_rules ORDER BY min_distance_km ASC');
  return rows;
}

async function createPricingRule(payload) {
  const { rows } = await query(
    `INSERT INTO pricing_rules (name, min_distance_km, max_distance_km, base_fare, per_km_rate, per_stop_rate)
     VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
    [
      payload.name,
      payload.minDistanceKm,
      payload.maxDistanceKm,
      payload.baseFare,
      payload.perKmRate,
      payload.perStopRate,
    ]
  );
  return rows[0];
}

async function togglePricingRule(ruleId, isActive) {
  const { rows } = await query('UPDATE pricing_rules SET is_active = $1 WHERE id = $2 RETURNING *', [
    isActive,
    ruleId,
  ]);
  if (!rows[0]) throw ApiError.notFound('Pricing rule not found');
  return rows[0];
}

module.exports = {
  listUsers,
  setUserActive,
  listPendingDrivers,
  reviewDriver,
  listAllTrips,
  getPlatformAnalytics,
  listPricingRules,
  createPricingRule,
  togglePricingRule,
};
