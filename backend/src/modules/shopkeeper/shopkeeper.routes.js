'use strict';

const express = require('express');
const { body, param } = require('express-validator');
const router = express.Router();

const { authenticate, authorize } = require('../../middleware/auth');
const validate = require('../../middleware/validate');
const ctrl = require('./shopkeeper.controller');

router.use(authenticate, authorize('shopkeeper'));

const shopValidator = [
  body('shopName').trim().notEmpty(),
  body('contactNumber').matches(/^[6-9]\d{9}$/),
  body('address').trim().notEmpty(),
  body('lat').isFloat({ min: -90, max: 90 }),
  body('lng').isFloat({ min: -180, max: 180 }),
];

/**
 * @openapi
 * /shopkeeper/shops:
 *   get:
 *     summary: List this shopkeeper's registered shops
 *     tags: [Shopkeeper]
 *     security: [{ bearerAuth: [] }]
 *   post:
 *     summary: Register a new shop location
 *     tags: [Shopkeeper]
 *     security: [{ bearerAuth: [] }]
 */
router.get('/shops', ctrl.listShopsHandler);
router.post('/shops', shopValidator, validate, ctrl.addShopHandler);
router.patch('/shops/:id', param('id').isUUID(), validate, ctrl.updateShopHandler);

/**
 * @openapi
 * /shopkeeper/deliveries/today:
 *   get:
 *     summary: Today's scheduled deliveries with live driver tracking info
 *     tags: [Shopkeeper]
 *     security: [{ bearerAuth: [] }]
 */
router.get('/deliveries/today', ctrl.todaysDeliveriesHandler);
router.get('/deliveries/history', ctrl.historyHandler);

module.exports = router;
