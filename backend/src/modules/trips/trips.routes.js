'use strict';

const express = require('express');
const router = express.Router();

const { authenticate, authorize } = require('../../middleware/auth');
const { locationPingLimiter } = require('../../middleware/rateLimiter');
const validate = require('../../middleware/validate');
const {
  createTripValidator,
  updateTripValidator,
  nearbyTripsValidator,
  bidValidator,
  selectBidValidator,
  locationPingValidator,
  deliverStopValidator,
  cancelTripValidator,
} = require('./trips.validators');
const { param } = require('express-validator');
const ctrl = require('./trips.controller');

router.use(authenticate);

/**
 * @openapi
 * /trips:
 *   post:
 *     summary: Distributor creates a draft trip with 1-40 delivery stops
 *     tags: [Trips]
 *     security: [{ bearerAuth: [] }]
 *   get:
 *     summary: Distributor lists their own trips (filterable, paginated)
 *     tags: [Trips]
 *     security: [{ bearerAuth: [] }]
 */
router.post('/', authorize('distributor'), createTripValidator, validate, ctrl.createHandler);
router.get('/', authorize('distributor'), ctrl.listMineHandler);

/**
 * @openapi
 * /trips/nearby:
 *   get:
 *     summary: Driver lists published trips within a radius of their location
 *     tags: [Trips]
 *     security: [{ bearerAuth: [] }]
 */
router.get('/nearby', authorize('driver'), nearbyTripsValidator, validate, ctrl.nearbyHandler);

router.get('/:id', param('id').isUUID(), validate, ctrl.getByIdHandler);

router.put('/:id', authorize('distributor'), updateTripValidator, validate, ctrl.updateHandler);
router.post(
  '/:id/publish',
  authorize('distributor'),
  param('id').isUUID(),
  validate,
  ctrl.publishHandler
);
router.post(
  '/:id/cancel',
  authorize('distributor'),
  cancelTripValidator,
  validate,
  ctrl.cancelHandler
);

/**
 * @openapi
 * /trips/{id}/bids:
 *   post:
 *     summary: Driver accepts or counter-offers on a published trip
 *     tags: [Trips]
 *     security: [{ bearerAuth: [] }]
 *   get:
 *     summary: Distributor views all bids received on their trip
 *     tags: [Trips]
 *     security: [{ bearerAuth: [] }]
 */
router.post('/:id/bids', authorize('driver'), bidValidator, validate, ctrl.placeBidHandler);
router.get('/:id/bids', authorize('distributor'), param('id').isUUID(), validate, ctrl.listBidsHandler);
router.post(
  '/:id/bids/:bidId/select',
  authorize('distributor'),
  selectBidValidator,
  validate,
  ctrl.selectBidHandler
);

router.post(
  '/:id/confirm-pickup',
  authorize('driver'),
  param('id').isUUID(),
  validate,
  ctrl.confirmPickupHandler
);

/**
 * @openapi
 * /trips/{id}/location:
 *   post:
 *     summary: Driver sends a live GPS ping while the trip is in progress
 *     tags: [Trips]
 *     security: [{ bearerAuth: [] }]
 */
router.post(
  '/:id/location',
  authorize('driver'),
  locationPingLimiter,
  locationPingValidator,
  validate,
  ctrl.locationPingHandler
);

/**
 * @openapi
 * /trips/{id}/track:
 *   get:
 *     summary: Live tracking - distributor, assigned driver, or relevant shopkeeper
 *     tags: [Trips]
 *     security: [{ bearerAuth: [] }]
 */
router.get('/:id/track', param('id').isUUID(), validate, ctrl.trackHandler);

router.post(
  '/:id/stops/:stopId/arrive',
  authorize('driver'),
  param('id').isUUID(),
  param('stopId').isUUID(),
  validate,
  ctrl.arriveHandler
);

/**
 * @openapi
 * /trips/{id}/stops/{stopId}/deliver:
 *   post:
 *     summary: Driver submits photo + GPS proof of delivery for a stop
 *     tags: [Trips]
 *     security: [{ bearerAuth: [] }]
 */
router.post(
  '/:id/stops/:stopId/deliver',
  authorize('driver'),
  deliverStopValidator,
  validate,
  ctrl.deliverHandler
);

module.exports = router;
