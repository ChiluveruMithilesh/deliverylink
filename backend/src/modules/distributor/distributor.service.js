'use strict';

const { query } = require('../../config/database');
const tripsService = require('../trips/trips.service');

/**
 * Search shops by name, for the "search shops" step when adding trip stops.
 * Optionally biased toward a lat/lng for nearest-first ordering.
 */
async function searchShops(searchTerm, lat, lng) {
  const { rows } = await query(
    `SELECT id, shop_name, contact_number, address, lat, lng
     FROM shops WHERE shop_name ILIKE $1
     ORDER BY shop_name ASC LIMIT 25`,
    [`%${searchTerm}%`]
  );

  if (lat != null && lng != null) {
    const { haversineDistanceKm } = require('../../utils/googleMaps');
    return rows
      .map((s) => ({ ...s, distanceKm: Math.round(haversineDistanceKm(lat, lng, s.lat, s.lng) * 10) / 10 }))
      .sort((a, b) => a.distanceKm - b.distanceKm);
  }
  return rows;
}

async function getDashboard(userId) {
  const distributorId = await tripsService.getDistributorIdForUser(userId);

  const { rows: statusCounts } = await query(
    `SELECT status, COUNT(*)::int AS count FROM trips WHERE distributor_id = $1 GROUP BY status`,
    [distributorId]
  );

  const { rows: activeTrips } = await query(
    `SELECT * FROM trips WHERE distributor_id = $1
       AND status IN ('published', 'assigned', 'pickup_confirmed', 'in_progress')
     ORDER BY created_at DESC LIMIT 10`,
    [distributorId]
  );

  return {
    statusCounts: statusCounts.reduce((acc, r) => ({ ...acc, [r.status]: r.count }), {}),
    activeTrips,
  };
}

/**
 * Aggregate reports: daily trips, completion rate, avg delivery time,
 * goods delivered, driver performance, shop-wise breakdown.
 */
async function getReports(userId, { fromDate, toDate } = {}) {
  const distributorId = await tripsService.getDistributorIdForUser(userId);
  const conditions = ['t.distributor_id = $1'];
  const values = [distributorId];
  let idx = 2;
  if (fromDate) {
    conditions.push(`t.created_at >= $${idx++}`);
    values.push(fromDate);
  }
  if (toDate) {
    conditions.push(`t.created_at <= $${idx++}`);
    values.push(toDate);
  }
  const whereClause = conditions.join(' AND ');

  const { rows: summary } = await query(
    `SELECT
       COUNT(*)::int AS total_trips,
       COUNT(*) FILTER (WHERE t.status = 'completed')::int AS completed_trips,
       COUNT(*) FILTER (WHERE t.status IN ('published','assigned','pickup_confirmed','in_progress'))::int AS pending_trips,
       COALESCE(SUM(t.total_quantity) FILTER (WHERE t.status = 'completed'), 0) AS goods_delivered,
       COALESCE(AVG(EXTRACT(EPOCH FROM (t.completed_at - t.started_at)) / 60)
         FILTER (WHERE t.status = 'completed'), 0) AS avg_delivery_time_min
     FROM trips t WHERE ${whereClause}`,
    values
  );

  const { rows: driverPerformance } = await query(
    `SELECT du.full_name AS driver_name, dr.vehicle_number, COUNT(*)::int AS trips_completed,
            COALESCE(AVG(EXTRACT(EPOCH FROM (t.completed_at - t.started_at)) / 60), 0) AS avg_delivery_time_min
     FROM trips t
     JOIN drivers dr ON dr.id = t.driver_id
     JOIN users du ON du.id = dr.user_id
     WHERE ${whereClause} AND t.status = 'completed'
     GROUP BY du.full_name, dr.vehicle_number
     ORDER BY trips_completed DESC LIMIT 20`,
    values
  );

  const { rows: shopWise } = await query(
    `SELECT ts.shop_name, COUNT(*)::int AS deliveries,
            COUNT(*) FILTER (WHERE ts.status = 'delivered')::int AS delivered
     FROM trip_stops ts
     JOIN trips t ON t.id = ts.trip_id
     WHERE ${whereClause}
     GROUP BY ts.shop_name
     ORDER BY deliveries DESC LIMIT 50`,
    values
  );

  return {
    summary: summary[0],
    driverPerformance,
    shopWise,
  };
}

module.exports = { searchShops, getDashboard, getReports };
