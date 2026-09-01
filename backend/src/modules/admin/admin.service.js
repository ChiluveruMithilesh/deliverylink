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

async function getStaleTrips() {
  const { rows } = await query(
    `SELECT t.id, t.goods_description, t.payment_offered, t.published_at,
            dist.business_name AS distributor_name
     FROM trips t
     JOIN distributors dist ON dist.id = t.distributor_id
     WHERE t.status = 'published'
       AND t.published_at < now() - INTERVAL '24 hours'
       AND NOT EXISTS (SELECT 1 FROM trip_bids b WHERE b.trip_id = t.id)
     ORDER BY t.published_at ASC
     LIMIT 10`
  );
  return rows;
}

async function getNeedsAttention() {
  const staleTrips = await getStaleTrips();
  const pendingDrivers = await listPendingDrivers();

  const items = [];

  if (pendingDrivers.length > 0) {
    items.push({
      type: 'pending_drivers',
      severity: 'warning',
      title: `${pendingDrivers.length} driver${pendingDrivers.length > 1 ? 's' : ''} awaiting verification`,
      subtitle: 'Review their documents to let them start accepting trips.',
    });
  }

  for (const trip of staleTrips) {
    const hoursAgo = Math.round((Date.now() - new Date(trip.published_at).getTime()) / (1000 * 60 * 60));
    items.push({
      type: 'stale_trip',
      severity: 'urgent',
      tripId: trip.id,
      title: `"${trip.goods_description}" has no driver interest`,
      subtitle: `Published by ${trip.distributor_name} ${hoursAgo}h ago, ₹${trip.payment_offered} offered.`,
    });
  }

  return items;
}

async function getPlatformAnalytics() {
  const { rows: userCounts } = await query(
    `SELECT role, COUNT(*)::int AS count FROM users GROUP BY role`
  );
  const { rows: tripCounts } = await query(
    `SELECT status, COUNT(*)::int AS count FROM trips GROUP BY status`
  );

  const { rows: overviewRows } = await query(
    `SELECT
       COUNT(*)::int AS total_trips,
       COUNT(*) FILTER (WHERE status = 'completed')::int AS completed_trips,
       COUNT(*) FILTER (WHERE status = 'cancelled')::int AS cancelled_trips,
       COALESCE(SUM(payment_offered) FILTER (WHERE status = 'completed'), 0) AS total_gmv,
       COALESCE(AVG(payment_offered) FILTER (WHERE status = 'completed'), 0) AS avg_order_value
     FROM trips`
  );
  const overview = overviewRows[0];
  const finishedCount = overview.completed_trips + overview.cancelled_trips;
  const completionRate = finishedCount > 0 ? Math.round((overview.completed_trips / finishedCount) * 1000) / 10 : 0;

  const { rows: periodRows } = await query(
    `SELECT
       COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE)::int AS today_trips,
       COALESCE(SUM(payment_offered) FILTER (WHERE status = 'completed' AND completed_at >= CURRENT_DATE), 0) AS today_gmv,
       COUNT(*) FILTER (WHERE created_at >= date_trunc('week', CURRENT_DATE))::int AS week_trips,
       COALESCE(SUM(payment_offered) FILTER (WHERE status = 'completed' AND completed_at >= date_trunc('week', CURRENT_DATE)), 0) AS week_gmv,
       COUNT(*) FILTER (WHERE created_at >= date_trunc('month', CURRENT_DATE))::int AS month_trips,
       COALESCE(SUM(payment_offered) FILTER (WHERE status = 'completed' AND completed_at >= date_trunc('month', CURRENT_DATE)), 0) AS month_gmv
     FROM trips`
  );
  const period = periodRows[0];

  const { rows: dailyTrend } = await query(
    `SELECT gs.day::date AS bucket, COALESCE(tc.trip_count, 0)::int AS trips, COALESCE(gm.gmv, 0) AS gmv
     FROM generate_series(CURRENT_DATE - INTERVAL '29 days', CURRENT_DATE, INTERVAL '1 day') AS gs(day)
     LEFT JOIN (
       SELECT date_trunc('day', created_at) AS day, COUNT(*) AS trip_count
       FROM trips WHERE created_at >= CURRENT_DATE - INTERVAL '29 days'
       GROUP BY 1
     ) tc ON tc.day = gs.day
     LEFT JOIN (
       SELECT date_trunc('day', completed_at) AS day, SUM(payment_offered) AS gmv
       FROM trips WHERE status = 'completed' AND completed_at >= CURRENT_DATE - INTERVAL '29 days'
       GROUP BY 1
     ) gm ON gm.day = gs.day
     ORDER BY gs.day ASC`
  );

  const { rows: monthlyTrend } = await query(
    `SELECT gs.month::date AS bucket, COALESCE(tc.trip_count, 0)::int AS trips, COALESCE(gm.gmv, 0) AS gmv
     FROM generate_series(
       date_trunc('month', CURRENT_DATE) - INTERVAL '11 months',
       date_trunc('month', CURRENT_DATE),
       INTERVAL '1 month'
     ) AS gs(month)
     LEFT JOIN (
       SELECT date_trunc('month', created_at) AS month, COUNT(*) AS trip_count
       FROM trips WHERE created_at >= date_trunc('month', CURRENT_DATE) - INTERVAL '11 months'
       GROUP BY 1
     ) tc ON tc.month = gs.month
     LEFT JOIN (
       SELECT date_trunc('month', completed_at) AS month, SUM(payment_offered) AS gmv
       FROM trips
       WHERE status = 'completed' AND completed_at >= date_trunc('month', CURRENT_DATE) - INTERVAL '11 months'
       GROUP BY 1
     ) gm ON gm.month = gs.month
     ORDER BY gs.month ASC`
  );

  const { rows: yearlyTrend } = await query(
    `SELECT gs.year::date AS bucket, COALESCE(tc.trip_count, 0)::int AS trips, COALESCE(gm.gmv, 0) AS gmv
     FROM generate_series(
       date_trunc('year', CURRENT_DATE) - INTERVAL '4 years',
       date_trunc('year', CURRENT_DATE),
       INTERVAL '1 year'
     ) AS gs(year)
     LEFT JOIN (
       SELECT date_trunc('year', created_at) AS year, COUNT(*) AS trip_count
       FROM trips WHERE created_at >= date_trunc('year', CURRENT_DATE) - INTERVAL '4 years'
       GROUP BY 1
     ) tc ON tc.year = gs.year
     LEFT JOIN (
       SELECT date_trunc('year', completed_at) AS year, SUM(payment_offered) AS gmv
       FROM trips
       WHERE status = 'completed' AND completed_at >= date_trunc('year', CURRENT_DATE) - INTERVAL '4 years'
       GROUP BY 1
     ) gm ON gm.year = gs.year
     ORDER BY gs.year ASC`
  );

  const { rows: topDistributors } = await query(
    `SELECT d.business_name,
            COUNT(*) FILTER (WHERE t.status = 'completed')::int AS completed_trips,
            COALESCE(SUM(t.payment_offered) FILTER (WHERE t.status = 'completed'), 0) AS total_gmv
     FROM trips t
     JOIN distributors d ON d.id = t.distributor_id
     GROUP BY d.business_name
     ORDER BY total_gmv DESC
     LIMIT 5`
  );

  const { rows: topDrivers } = await query(
    `SELECT u.full_name AS driver_name,
            COUNT(*) FILTER (WHERE t.status = 'completed')::int AS completed_trips,
            COALESCE(SUM(t.payment_offered) FILTER (WHERE t.status = 'completed'), 0) AS total_earnings
     FROM trips t
     JOIN drivers dr ON dr.id = t.driver_id
     JOIN users u ON u.id = dr.user_id
     WHERE t.driver_id IS NOT NULL
     GROUP BY u.full_name
     ORDER BY total_earnings DESC
     LIMIT 5`
  );

  const needsAttention = await getNeedsAttention();

  const toSeries = (rows) =>
    rows.map((r) => ({
      date: r.bucket.toISOString().slice(0, 10),
      trips: r.trips,
      gmv: Number(r.gmv),
    }));

  return {
    usersByRole: userCounts.reduce((acc, r) => ({ ...acc, [r.role]: r.count }), {}),
    tripsByStatus: tripCounts.reduce((acc, r) => ({ ...acc, [r.status]: r.count }), {}),
    overview: {
      totalTrips: overview.total_trips,
      completedTrips: overview.completed_trips,
      cancelledTrips: overview.cancelled_trips,
      totalGmv: Number(overview.total_gmv),
      avgOrderValue: Math.round(Number(overview.avg_order_value) * 100) / 100,
      completionRate,
    },
    today: { trips: period.today_trips, gmv: Number(period.today_gmv) },
    thisWeek: { trips: period.week_trips, gmv: Number(period.week_gmv) },
    thisMonth: { trips: period.month_trips, gmv: Number(period.month_gmv) },
    dailyTrend: toSeries(dailyTrend),
    monthlyTrend: toSeries(monthlyTrend),
    yearlyTrend: toSeries(yearlyTrend),
    needsAttention,
    topDistributors: topDistributors.map((d) => ({
      businessName: d.business_name,
      completedTrips: d.completed_trips,
      totalGmv: Number(d.total_gmv),
    })),
    topDrivers: topDrivers.map((d) => ({
      driverName: d.driver_name,
      completedTrips: d.completed_trips,
      totalEarnings: Number(d.total_earnings),
    })),
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