'use strict';

const { body, query: queryValidator, param } = require('express-validator');

const createTripValidator = [
  body('pickupAddress').trim().notEmpty().withMessage('pickupAddress is required'),
  body('pickupLat').isFloat({ min: -90, max: 90 }).withMessage('pickupLat must be a valid latitude'),
  body('pickupLng').isFloat({ min: -180, max: 180 }).withMessage('pickupLng must be a valid longitude'),
  body('goodsDescription').trim().notEmpty().withMessage('goodsDescription is required'),
  body('totalQuantity').isInt({ min: 1 }).withMessage('totalQuantity must be a positive integer'),
  body('goodsValue').isFloat({ min: 0 }).withMessage('goodsValue must be a non-negative number'),
  body('paymentOffered').isFloat({ min: 0 }).withMessage('paymentOffered must be a non-negative number'),
  body('stops').isArray({ min: 1, max: 40 }).withMessage('stops must contain between 1 and 40 locations'),
  body('stops.*.shopName').trim().notEmpty().withMessage('each stop requires a shopName'),
  body('stops.*.contactNumber')
    .matches(/^[6-9]\d{9}$/)
    .withMessage('each stop requires a valid 10-digit contactNumber'),
  body('stops.*.lat').isFloat({ min: -90, max: 90 }).withMessage('each stop requires a valid lat'),
  body('stops.*.lng').isFloat({ min: -180, max: 180 }).withMessage('each stop requires a valid lng'),
  body('stops.*.quantity').isInt({ min: 1 }).withMessage('each stop requires a positive quantity'),
  body('stops.*.unitType')
    .isIn(['cartons', 'bags', 'boxes'])
    .withMessage('each stop unitType must be cartons, bags, or boxes'),
  body('stops.*.shopId').optional().isUUID().withMessage('shopId must be a valid UUID if provided'),
  body('stops.*.notes').optional().isString(),
];

const updateTripValidator = [
  param('id').isUUID().withMessage('Invalid trip id'),
  body('pickupAddress').optional().trim().notEmpty(),
  body('pickupLat').optional().isFloat({ min: -90, max: 90 }),
  body('pickupLng').optional().isFloat({ min: -180, max: 180 }),
  body('goodsDescription').optional().trim().notEmpty(),
  body('totalQuantity').optional().isInt({ min: 1 }),
  body('goodsValue').optional().isFloat({ min: 0 }),
  body('paymentOffered').optional().isFloat({ min: 0 }),
  body('stops').optional().isArray({ min: 1, max: 40 }),
];

const nearbyTripsValidator = [
  queryValidator('lat').isFloat({ min: -90, max: 90 }).withMessage('lat is required'),
  queryValidator('lng').isFloat({ min: -180, max: 180 }).withMessage('lng is required'),
  queryValidator('radiusKm').optional().isFloat({ min: 1, max: 100 }),
];

const bidValidator = [
  param('id').isUUID(),
  body('offeredAmount').isFloat({ min: 0 }).withMessage('offeredAmount must be a non-negative number'),
];

const selectBidValidator = [param('id').isUUID(), param('bidId').isUUID()];

const locationPingValidator = [
  param('id').isUUID(),
  body('lat').isFloat({ min: -90, max: 90 }),
  body('lng').isFloat({ min: -180, max: 180 }),
];

const deliverStopValidator = [
  param('id').isUUID(),
  param('stopId').isUUID(),
  body('capturedLat').isFloat({ min: -90, max: 90 }),
  body('capturedLng').isFloat({ min: -180, max: 180 }),
  body('photoUrl').notEmpty().withMessage('photoUrl is required as proof of delivery'),
  body('otp').optional().isLength({ min: 4, max: 6 }),
];

const cancelTripValidator = [
  param('id').isUUID(),
  body('reason').optional().isString().isLength({ max: 500 }),
];

module.exports = {
  createTripValidator,
  updateTripValidator,
  nearbyTripsValidator,
  bidValidator,
  selectBidValidator,
  locationPingValidator,
  deliverStopValidator,
  cancelTripValidator,
};
