'use strict';

const { withTransaction, query } = require('../../config/database');
const { cacheSet, cacheGet } = require('../../config/redis');
const { getOptimizedRoute, haversineDistanceKm } = require('../../utils/googleMaps');
const ApiError = require('../../utils/ApiError');
const logger = require('../../utils/logger');
const notificationsService = require('../notifications/notifications.service');

const OTP_LENGTH = 4;

function generateOtp() {
  return String(Math.floor(1000 + Math.random() * 9000)).slice(0, OTP_LENGTH);
}

async function getDistributorIdForUser(userId) {
  const { rows } = await query('SELECT id FROM distributors WHERE user_id = $1', [userId]);
  if (!rows[0]) throw ApiError.forbidden('No distributor profile found for this account');
  return rows[0].id;
}

async function getDriverIdForUser(userId) {
  const { rows } = await query('SELECT id FROM drivers WHERE user_id = $1', [userId]);
  if (!rows[0]) throw ApiError.forbidden('No driver profile found for this account');
  return rows[0].id;
}

/**
 * Creates a trip in 'draft' status along with all its stops.
 * Stops are re-ordered via route optimization before being persisted.
 */
async function createTrip(userId, payload) {
  const distributorId = await getDistributorIdForUser(userId);

  const route = await getOptimizedRoute(payload.pickupLat, payload.pickupLng, payload.stops);

  return withTransaction(async (client) => {
    const tripResult = await client.query(
      `INSERT INTO trips
         (distributor_id, pickup_address, pickup_lat, pickup_lng, goods_description,
          total_quantity, goods_value, payment_offered, status, total_stops,
          optimized_route, estimated_distance_km, estimated_duration_min)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'draft',$9,$10,$11,$12)
       RETURNING *`,
      [
        distributorId,
        payload.pickupAddress,
        payload.pickupLat,
        payload.pickupLng,
        payload.goodsDescription,
        payload.totalQuantity,
        payload.goodsValue,
        payload.paymentOffered,
        payload.stops.length,
        JSON.stringify({ source: route.source, polyline: route.polyline }),
        route.totalDistanceKm,
        route.totalDurationMin,
      ]
    );
    const trip = tripResult.rows[0];

    let seq = 1;
    const insertedStops = [];
    for (const stop of route.orderedStops) {
      const otp = generateOtp();
      const stopResult = await client.query(
        `INSERT INTO trip_stops
           (trip_id, shop_id, sequence_number, shop_name, contact_number, lat, lng,
            quantity, unit_type, notes, status, delivery_otp)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'pending',$11)
         RETURNING *`,
        [
          trip.id,
          stop.shopId || null,
          seq++,
          stop.shopName,
          stop.contactNumber,
          stop.lat,
          stop.lng,
          stop.quantity,
          stop.unitType,
          stop.notes || null,
          otp,
        ]
      );
      insertedStops.push(stopResult.rows[0]);
    }

    logger.info('Trip created', { tripId: trip.id, distributorId, stopCount: insertedStops.length });
    return { ...trip, stops: insertedStops };
  });
}

/**
 * Only draft trips can be freely edited. Editing replaces all stops
 * and re-runs route optimization. Once published/assigned, use
 * cancelTrip + createTrip instead of mutating a live trip.
 */
async function updateTrip(userId, tripId, payload) {
  const distributorId = await getDistributorIdForUser(userId);
  const trip = await getOwnedDraftTrip(tripId, distributorId);

  const stops = payload.stops || (await getStopsForTrip(tripId));
  const pickupLat = payload.pickupLat ?? trip.pickup_lat;
  const pickupLng = payload.pickupLng ?? trip.pickup_lng;

  const route = payload.stops ? await getOptimizedRoute(pickupLat, pickupLng, stops) : null;

  return withTransaction(async (client) => {
    const fields = [];
    const values = [];
    let idx = 1;

    const mapping = {
      pickupAddress: 'pickup_address',
      pickupLat: 'pickup_lat',
      pickupLng: 'pickup_lng',
      goodsDescription: 'goods_description',
      totalQuantity: 'total_quantity',
      goodsValue: 'goods_value',
      paymentOffered: 'payment_offered',
    };
    for (const [key, column] of Object.entries(mapping)) {
      if (payload[key] !== undefined) {
        fields.push(`${column} = $${idx++}`);
        values.push(payload[key]);
      }
    }
    if (route) {
      fields.push(`total_stops = $${idx++}`);
      values.push(stops.length);
      fields.push(`optimized_route = $${idx++}`);
      values.push(JSON.stringify({ source: route.source, polyline: route.polyline }));
      fields.push(`estimated_distance_km = $${idx++}`);
      values.push(route.totalDistanceKm);
      fields.push(`estimated_duration_min = $${idx++}`);
      values.push(route.totalDurationMin);
    }

    if (fields.length > 0) {
      values.push(tripId);
      await client.query(`UPDATE trips SET ${fields.join(', ')} WHERE id = $${idx}`, values);
    }

    if (route) {
      await client.query('DELETE FROM trip_stops WHERE trip_id = $1', [tripId]);
      let seq = 1;
      for (const stop of route.orderedStops) {
        const otp = generateOtp();
        await client.query(
          `INSERT INTO trip_stops
             (trip_id, shop_id, sequence_number, shop_name, contact_number, lat, lng,
              quantity, unit_type, notes, status, delivery_otp)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'pending',$11)`,
          [
            tripId,
            stop.shopId || null,
            seq++,
            stop.shopName,
            stop.contactNumber,
            stop.lat,
            stop.lng,
            stop.quantity,
            stop.unitType,
            stop.notes || null,
            otp,
          ]
        );
      }
    }

    const { rows } = await client.query('SELECT * FROM trips WHERE id = $1', [tripId]);
    return { ...rows[0], stops: await getStopsForTrip(tripId, client) };
  });
}

async function publishTrip(userId, tripId) {
  const distributorId = await getDistributorIdForUser(userId);
  const trip = await getOwnedDraftTrip(tripId, distributorId);

  await query(`UPDATE trips SET status = 'published', published_at = now() WHERE id = $1`, [tripId]);

  await notifyNearbyDrivers(trip);

  return getTripById(tripId);
}

async function cancelTrip(userId, tripId, reason) {
  const distributorId = await getDistributorIdForUser(userId);
  const { rows } = await query('SELECT * FROM trips WHERE id = $1 AND distributor_id = $2', [
    tripId,
    distributorId,
  ]);
  const trip = rows[0];
  if (!trip) throw ApiError.notFound('Trip not found');
  if (['completed', 'cancelled', 'in_progress'].includes(trip.status)) {
    throw ApiError.badRequest(`Cannot cancel a trip that is already ${trip.status}`);
  }

  await query(
    `UPDATE trips SET status = 'cancelled', cancelled_at = now(), cancellation_reason = $2 WHERE id = $1`,
    [tripId, reason || null]
  );

  if (trip.driver_id) {
    const { rows: driverRows } = await query('SELECT user_id FROM drivers WHERE id = $1', [
      trip.driver_id,
    ]);
    if (driverRows[0]) {
      await notificationsService.notifyUser({
        userId: driverRows[0].user_id,
        tripId,
        title: 'Trip Cancelled',
        body: 'The distributor has cancelled this delivery trip.',
      });
    }
  }

  return getTripById(tripId);
}

async function getOwnedDraftTrip(tripId, distributorId) {
  const { rows } = await query('SELECT * FROM trips WHERE id = $1 AND distributor_id = $2', [
    tripId,
    distributorId,
  ]);
  const trip = rows[0];
  if (!trip) throw ApiError.notFound('Trip not found');
  if (trip.status !== 'draft') {
    throw ApiError.badRequest('Only draft trips can be edited or published');
  }
  return trip;
}

async function getStopsForTrip(tripId, client = null) {
  const runner = client || { query };
  const { rows } = await runner.query(
    'SELECT * FROM trip_stops WHERE trip_id = $1 ORDER BY sequence_number ASC',
    [tripId]
  );
  return rows;
}

async function getTripById(tripId) {
  const { rows } = await query(
    `SELECT t.*, d.business_name AS distributor_name, u.full_name AS driver_name,
            dr.vehicle_number, dr.vehicle_type
     FROM trips t
     JOIN distributors d ON d.id = t.distributor_id
     LEFT JOIN drivers dr ON dr.id = t.driver_id
     LEFT JOIN users u ON u.id = dr.user_id
     WHERE t.id = $1`,
    [tripId]
  );
  const trip = rows[0];
  if (!trip) throw ApiError.notFound('Trip not found');
  trip.stops = await getStopsForTrip(tripId);
  return trip;
}

async function listDistributorTrips(userId, { status, page = 1, limit = 20 } = {}) {
  const distributorId = await getDistributorIdForUser(userId);
  const conditions = ['distributor_id = $1'];
  const values = [distributorId];
  let idx = 2;
  if (status) {
    conditions.push(`status = $${idx++}`);
    values.push(status);
  }
  const offset = (page - 1) * limit;
  values.push(limit, offset);

  const { rows } = await query(
    `SELECT * FROM trips WHERE ${conditions.join(' AND ')}
     ORDER BY created_at DESC LIMIT $${idx} OFFSET $${idx + 1}`,
    values
  );
  return rows;
}

/**
 * Trips published and within radiusKm of the driver's current position,
 * that the driver hasn't already bid on or been assigned elsewhere.
 */
async function listNearbyTrips(userId, lat, lng, radiusKm = 20) {
  const driverId = await getDriverIdForUser(userId);

  const { rows } = await query(
    `SELECT t.*, d.business_name AS distributor_name
     FROM trips t
     JOIN distributors d ON d.id = t.distributor_id
     WHERE t.status = 'published'
       AND t.id NOT IN (SELECT trip_id FROM trip_bids WHERE driver_id = $1)
     ORDER BY t.published_at DESC
     LIMIT 200`,
    [driverId]
  );

  return rows
    .map((trip) => ({
      ...trip,
      distanceFromDriverKm:
        Math.round(haversineDistanceKm(lat, lng, trip.pickup_lat, trip.pickup_lng) * 10) / 10,
    }))
    .filter((trip) => trip.distanceFromDriverKm <= radiusKm)
    .sort((a, b) => a.distanceFromDriverKm - b.distanceFromDriverKm);
}

async function notifyNearbyDrivers(trip) {
  const { rows: onlineDrivers } = await query(
    `SELECT user_id, current_lat, current_lng FROM drivers
     WHERE is_online = TRUE AND verification_status = 'approved'
       AND current_lat IS NOT NULL AND current_lng IS NOT NULL`
  );

  const nearby = onlineDrivers.filter(
    (d) => haversineDistanceKm(d.current_lat, d.current_lng, trip.pickup_lat, trip.pickup_lng) <= 20
  );

  await Promise.all(
    nearby.map((d) =>
      notificationsService.notifyUser({
        userId: d.user_id,
        tripId: trip.id,
        title: 'New delivery trip nearby',
        body: `A new trip with ${trip.total_stops} stops is available near your location.`,
      })
    )
  );
}

/**
 * Driver accepts or counter-offers on a published trip.
 * Distributor is notified either way.
 */
async function placeBid(userId, tripId, offeredAmount) {
  const driverId = await getDriverIdForUser(userId);

  const { rows: tripRows } = await query('SELECT * FROM trips WHERE id = $1', [tripId]);
  const trip = tripRows[0];
  if (!trip) throw ApiError.notFound('Trip not found');
  if (trip.status !== 'published') {
    throw ApiError.badRequest('This trip is no longer accepting bids');
  }

  const { rows: driverRows } = await query('SELECT id FROM drivers WHERE id = $1', [driverId]);
  if (!driverRows[0]) throw ApiError.forbidden('Driver profile not found');

  const status = offeredAmount === Number(trip.payment_offered) ? 'accepted' : 'countered';

  const { rows } = await query(
    `INSERT INTO trip_bids (trip_id, driver_id, offered_amount, status)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (trip_id, driver_id)
     DO UPDATE SET offered_amount = $3, status = $4, updated_at = now()
     RETURNING *`,
    [tripId, driverId, offeredAmount, status]
  );

  const { rows: distRows } = await query(
    `SELECT u.id AS user_id FROM distributors dist JOIN users u ON u.id = dist.user_id
     WHERE dist.id = $1`,
    [trip.distributor_id]
  );
  if (distRows[0]) {
    await notificationsService.notifyUser({
      userId: distRows[0].user_id,
      tripId,
      title: status === 'accepted' ? 'Driver accepted your trip' : 'New counter-offer received',
      body:
        status === 'accepted'
          ? 'A driver has accepted your delivery payment offer.'
          : `A driver has countered with ₹${offeredAmount}.`,
    });
  }

  return rows[0];
}

async function listBids(userId, tripId) {
  const distributorId = await getDistributorIdForUser(userId);
  const { rows: tripRows } = await query('SELECT id FROM trips WHERE id = $1 AND distributor_id = $2', [
    tripId,
    distributorId,
  ]);
  if (!tripRows[0]) throw ApiError.notFound('Trip not found');

  const { rows } = await query(
    `SELECT b.*, u.full_name AS driver_name, u.phone AS driver_phone,
            dr.vehicle_type, dr.vehicle_number, dr.rating
     FROM trip_bids b
     JOIN drivers dr ON dr.id = b.driver_id
     JOIN users u ON u.id = dr.user_id
     WHERE b.trip_id = $1
     ORDER BY b.offered_amount ASC`,
    [tripId]
  );
  return rows;
}

/**
 * Distributor confirms a specific driver's bid. Assigns the driver,
 * moves the trip to 'assigned', and notifies the driver + all shopkeepers
 * whose shops are part of this trip.
 */
async function selectBid(userId, tripId, bidId) {
  const distributorId = await getDistributorIdForUser(userId);

  return withTransaction(async (client) => {
    const { rows: tripRows } = await client.query(
      'SELECT * FROM trips WHERE id = $1 AND distributor_id = $2 FOR UPDATE',
      [tripId, distributorId]
    );
    const trip = tripRows[0];
    if (!trip) throw ApiError.notFound('Trip not found');
    if (trip.status !== 'published') {
      throw ApiError.badRequest('This trip has already been assigned or is no longer open');
    }

    const { rows: bidRows } = await client.query(
      'SELECT * FROM trip_bids WHERE id = $1 AND trip_id = $2',
      [bidId, tripId]
    );
    const bid = bidRows[0];
    if (!bid) throw ApiError.notFound('Bid not found');

    await client.query(
      `UPDATE trips SET status = 'assigned', driver_id = $1, assigned_at = now() WHERE id = $2`,
      [bid.driver_id, tripId]
    );
    await client.query(`UPDATE trip_bids SET status = 'accepted' WHERE id = $1`, [bidId]);
    await client.query(
      `UPDATE trip_bids SET status = 'rejected' WHERE trip_id = $1 AND id != $2 AND status != 'rejected'`,
      [tripId, bidId]
    );

    const { rows: driverUserRows } = await client.query(
      'SELECT user_id FROM drivers WHERE id = $1',
      [bid.driver_id]
    );
    if (driverUserRows[0]) {
      await notificationsService.notifyUser({
        userId: driverUserRows[0].user_id,
        tripId,
        title: 'Trip assigned to you',
        body: 'You have been selected for a delivery trip. Head to the pickup location.',
      });
    }

    const stops = await getStopsForTrip(tripId, client);
    const shopIds = stops.filter((s) => s.shop_id).map((s) => s.shop_id);
    if (shopIds.length > 0) {
      const shopUserRows = await client.query(
        `SELECT DISTINCT s.shopkeeper_user_id FROM shops s WHERE s.id = ANY($1::uuid[])`,
        [shopIds]
      );
      await Promise.all(
        shopUserRows.rows.map((r) =>
          notificationsService.notifyUser({
            userId: r.shopkeeper_user_id,
            tripId,
            title: 'Delivery scheduled',
            body: 'A distributor has scheduled a delivery for your shop today.',
          })
        )
      );
    }

    return getTripById(tripId);
  });
}

async function confirmPickup(userId, tripId) {
  const driverId = await getDriverIdForUser(userId);
  const { rows } = await query('SELECT * FROM trips WHERE id = $1 AND driver_id = $2', [
    tripId,
    driverId,
  ]);
  const trip = rows[0];
  if (!trip) throw ApiError.notFound('Trip not found or not assigned to you');
  if (trip.status !== 'assigned') {
    throw ApiError.badRequest('Trip must be in assigned status to confirm pickup');
  }

  await query(`UPDATE trips SET status = 'in_progress', started_at = now() WHERE id = $1`, [tripId]);

  const { rows: distRows } = await query(
    `SELECT u.id AS user_id FROM distributors dist JOIN users u ON u.id = dist.user_id
     WHERE dist.id = $1`,
    [trip.distributor_id]
  );
  if (distRows[0]) {
    await notificationsService.notifyUser({
      userId: distRows[0].user_id,
      tripId,
      title: 'Driver started the trip',
      body: 'The driver has picked up the goods and started the delivery route.',
    });
  }

  return getTripById(tripId);
}

/**
 * Records a live GPS ping, updates the driver's current position,
 * and caches the latest point in Redis for fast tracking reads.
 */
async function recordLocationPing(userId, tripId, lat, lng) {
  const driverId = await getDriverIdForUser(userId);
  const { rows } = await query('SELECT id FROM trips WHERE id = $1 AND driver_id = $2', [
    tripId,
    driverId,
  ]);
  if (!rows[0]) throw ApiError.notFound('Trip not found or not assigned to you');

  await query('INSERT INTO location_history (trip_id, driver_id, lat, lng) VALUES ($1, $2, $3, $4)', [
    tripId,
    driverId,
    lat,
    lng,
  ]);
  await query(
    'UPDATE drivers SET current_lat = $1, current_lng = $2, current_location_updated_at = now() WHERE id = $3',
    [lat, lng, driverId]
  );
  await cacheSet(`trip:${tripId}:location`, { lat, lng, recordedAt: new Date().toISOString() }, 120);

  return { tripId, lat, lng };
}

async function hasShopAccessToTrip(shopkeeperUserId, tripId) {
  const { rows } = await query(
    `SELECT 1 FROM trip_stops ts
     JOIN shops s ON s.id = ts.shop_id
     WHERE ts.trip_id = $1 AND s.shopkeeper_user_id = $2 LIMIT 1`,
    [tripId, shopkeeperUserId]
  );
  return rows.length > 0;
}

async function getDriverIdForUserSafe(userId) {
  const { rows } = await query('SELECT id FROM drivers WHERE user_id = $1', [userId]);
  return rows[0]?.id || null;
}

/**
 * Live tracking read model. Accessible to the owning distributor,
 * the assigned driver, or a shopkeeper whose shop is on the route.
 */
async function getLiveTracking(requestingUser, tripId) {
  const trip = await getTripById(tripId);

  const isDistributorOwner =
    requestingUser.role === 'distributor' &&
    (await getDistributorIdForUser(requestingUser.id)) === trip.distributor_id;
  const isAssignedDriver =
    requestingUser.role === 'driver' &&
    trip.driver_id === (await getDriverIdForUserSafe(requestingUser.id));
  const isRelevantShopkeeper =
    requestingUser.role === 'shopkeeper' && (await hasShopAccessToTrip(requestingUser.id, tripId));

  if (
    !isDistributorOwner &&
    !isAssignedDriver &&
    !isRelevantShopkeeper &&
    requestingUser.role !== 'admin'
  ) {
    throw ApiError.forbidden('You do not have access to track this trip');
  }

  const cached = await cacheGet(`trip:${tripId}:location`);
  return {
    tripId: trip.id,
    status: trip.status,
    currentLocation: cached || null,
    stops: trip.stops.map((s) => ({
      id: s.id,
      sequenceNumber: s.sequence_number,
      shopName: s.shop_name,
      status: s.status,
      arrivedAt: s.arrived_at,
      deliveredAt: s.delivered_at,
    })),
  };
}

async function arriveAtStop(userId, tripId, stopId) {
  const driverId = await getDriverIdForUser(userId);
  const { rows: tripRows } = await query('SELECT * FROM trips WHERE id = $1 AND driver_id = $2', [
    tripId,
    driverId,
  ]);
  if (!tripRows[0]) throw ApiError.notFound('Trip not found or not assigned to you');

  const { rows: stopRows } = await query(
    `UPDATE trip_stops SET status = 'arrived', arrived_at = now()
     WHERE id = $1 AND trip_id = $2 RETURNING *`,
    [stopId, tripId]
  );
  const stop = stopRows[0];
  if (!stop) throw ApiError.notFound('Stop not found');

  if (stop.shop_id) {
    const { rows: shopRows } = await query('SELECT shopkeeper_user_id FROM shops WHERE id = $1', [
      stop.shop_id,
    ]);
    if (shopRows[0]) {
      await notificationsService.notifyUser({
        userId: shopRows[0].shopkeeper_user_id,
        tripId,
        title: 'Driver is approaching',
        body: `The delivery driver has arrived near ${stop.shop_name}.`,
      });
    }
  }

  return stop;
}

/**
 * Records photo + GPS + timestamp proof of delivery for a stop,
 * marks it delivered, and auto-completes the trip once every
 * stop is delivered (or explicitly failed/skipped).
 */
async function deliverStop(userId, tripId, stopId, proof) {
  const driverId = await getDriverIdForUser(userId);

  return withTransaction(async (client) => {
    const { rows: tripRows } = await client.query(
      'SELECT * FROM trips WHERE id = $1 AND driver_id = $2 FOR UPDATE',
      [tripId, driverId]
    );
    const trip = tripRows[0];
    if (!trip) throw ApiError.notFound('Trip not found or not assigned to you');

    const { rows: stopRows } = await client.query(
      'SELECT * FROM trip_stops WHERE id = $1 AND trip_id = $2',
      [stopId, tripId]
    );
    const stop = stopRows[0];
    if (!stop) throw ApiError.notFound('Stop not found');
    if (stop.status === 'delivered') throw ApiError.badRequest('Stop already marked as delivered');

    if (proof.otp && stop.delivery_otp && proof.otp !== stop.delivery_otp) {
      throw ApiError.badRequest('Delivery OTP does not match');
    }

    await client.query(`UPDATE trip_stops SET status = 'delivered', delivered_at = now() WHERE id = $1`, [
      stopId,
    ]);
    await client.query(
      `INSERT INTO delivery_proofs (trip_stop_id, photo_url, captured_lat, captured_lng, signature_url)
       VALUES ($1, $2, $3, $4, $5)`,
      [stopId, proof.photoUrl, proof.capturedLat, proof.capturedLng, proof.signatureUrl || null]
    );

    if (stop.shop_id) {
      const { rows: shopRows } = await client.query('SELECT shopkeeper_user_id FROM shops WHERE id = $1', [
        stop.shop_id,
      ]);
      if (shopRows[0]) {
        await notificationsService.notifyUser({
          userId: shopRows[0].shopkeeper_user_id,
          tripId,
          title: 'Delivery completed',
          body: `Your delivery has been completed.`,
        });
      }
    }

    const { rows: remaining } = await client.query(
      `SELECT COUNT(*)::int AS cnt FROM trip_stops
       WHERE trip_id = $1 AND status NOT IN ('delivered', 'failed', 'skipped')`,
      [tripId]
    );

    if (remaining[0].cnt === 0) {
      await client.query(`UPDATE trips SET status = 'completed', completed_at = now() WHERE id = $1`, [
        tripId,
      ]);
      await client.query(
        `UPDATE drivers SET total_trips = total_trips + 1,
           total_distance_km = total_distance_km + COALESCE($2, 0)
         WHERE id = $1`,
        [driverId, trip.estimated_distance_km]
      );
      await client.query(`UPDATE distributors SET total_trips = total_trips + 1 WHERE id = $1`, [
        trip.distributor_id,
      ]);

      const { rows: distRows } = await client.query(
        `SELECT u.id AS user_id FROM distributors dist JOIN users u ON u.id = dist.user_id WHERE dist.id = $1`,
        [trip.distributor_id]
      );
      if (distRows[0]) {
        await notificationsService.notifyUser({
          userId: distRows[0].user_id,
          tripId,
          title: 'Trip completed',
          body: 'All stops on this trip have been delivered successfully.',
        });
      }
    }

    return getTripById(tripId);
  });
}

module.exports = {
  createTrip,
  updateTrip,
  publishTrip,
  cancelTrip,
  getTripById,
  listDistributorTrips,
  listNearbyTrips,
  placeBid,
  listBids,
  selectBid,
  confirmPickup,
  recordLocationPing,
  getLiveTracking,
  arriveAtStop,
  deliverStop,
  getDistributorIdForUser,
  getDriverIdForUser,
};
