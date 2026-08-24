'use strict';

const { query } = require('../../config/database');
const ApiError = require('../../utils/ApiError');

async function getProfile(userId) {
  const { rows } = await query(
    `SELECT d.*, u.full_name, u.phone, u.email FROM drivers d
     JOIN users u ON u.id = d.user_id WHERE d.user_id = $1`,
    [userId]
  );
  if (!rows[0]) throw ApiError.notFound('Driver profile not found');
  return rows[0];
}

async function updateProfile(userId, payload) {
  const mapping = {
    vehicleType: 'vehicle_type',
    vehicleNumber: 'vehicle_number',
    vehicleCapacityKg: 'vehicle_capacity_kg',
    drivingLicenceNumber: 'driving_licence_number',
    drivingLicencePhotoUrl: 'driving_licence_photo_url',
    vehicleRcPhotoUrl: 'vehicle_rc_photo_url',
    insurancePhotoUrl: 'insurance_photo_url',
    profilePhotoUrl: 'profile_photo_url',
    aadhaarNumber: 'aadhaar_number',
  };

  const fields = [];
  const values = [];
  let idx = 1;
  for (const [key, column] of Object.entries(mapping)) {
    if (payload[key] !== undefined) {
      fields.push(`${column} = $${idx++}`);
      values.push(payload[key]);
    }
  }
  if (fields.length === 0) return getProfile(userId);

  // Any profile edit (esp. documents) resets verification to pending for admin re-review.
  fields.push(`verification_status = 'pending'`);

  values.push(userId);
  await query(`UPDATE drivers SET ${fields.join(', ')} WHERE user_id = $${idx}`, values);
  return getProfile(userId);
}

async function setOnlineStatus(userId, isOnline, lat, lng) {
  await query(
    `UPDATE drivers SET is_online = $1, current_lat = COALESCE($2, current_lat),
       current_lng = COALESCE($3, current_lng), current_location_updated_at = now()
     WHERE user_id = $4`,
    [isOnline, lat ?? null, lng ?? null, userId]
  );
  return getProfile(userId);
}

async function getDashboard(userId) {
  const profile = await getProfile(userId);

  // Previously LIMIT 1 - which meant a driver juggling multiple assigned
  // trips (perfectly possible: nothing stops two distributors selecting
  // the same driver) would only ever see the most recent one, with
  // earlier ones silently hidden even though still active.
  const { rows: activeTripRows } = await query(
    `SELECT * FROM trips WHERE driver_id = $1 AND status IN ('assigned', 'pickup_confirmed', 'in_progress')
     ORDER BY assigned_at DESC`,
    [profile.id]
  );

  const { rows: earningsRows } = await query(
    `SELECT COALESCE(SUM(payment_offered), 0) AS total_earnings, COUNT(*)::int AS completed_trips
     FROM trips WHERE driver_id = $1 AND status = 'completed'`,
    [profile.id]
  );

  return {
    profile,
    activeTrips: activeTripRows,
    totalEarnings: Number(earningsRows[0].total_earnings),
    completedTrips: earningsRows[0].completed_trips,
  };
}

async function getTripHistory(userId, { page = 1, limit = 20 } = {}) {
  const profile = await getProfile(userId);
  const offset = (page - 1) * limit;
  const { rows } = await query(
    `SELECT * FROM trips WHERE driver_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
    [profile.id, limit, offset]
  );
  return rows;
}

async function getEarningsReport(userId, { fromDate, toDate } = {}) {
  const profile = await getProfile(userId);
  const conditions = [`driver_id = $1`, `status = 'completed'`];
  const values = [profile.id];
  let idx = 2;
  if (fromDate) {
    conditions.push(`completed_at >= $${idx++}`);
    values.push(fromDate);
  }
  if (toDate) {
    conditions.push(`completed_at <= $${idx++}`);
    values.push(toDate);
  }

  const { rows } = await query(
    `SELECT COUNT(*)::int AS trips_completed,
            COALESCE(SUM(payment_offered), 0) AS total_earnings,
            COALESCE(SUM(estimated_distance_km), 0) AS total_distance_km
     FROM trips WHERE ${conditions.join(' AND ')}`,
    values
  );

  const { rows: bidStats } = await query(
    `SELECT COUNT(*)::int AS total_bids,
            COUNT(*) FILTER (WHERE status = 'accepted')::int AS accepted_bids
     FROM trip_bids WHERE driver_id = $1`,
    [profile.id]
  );

  const acceptanceRate =
    bidStats[0].total_bids > 0
      ? Math.round((bidStats[0].accepted_bids / bidStats[0].total_bids) * 1000) / 10
      : 0;

  return { ...rows[0], acceptanceRate };
}

module.exports = { getProfile, updateProfile, setOnlineStatus, getDashboard, getTripHistory, getEarningsReport };
