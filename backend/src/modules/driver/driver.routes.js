'use strict';

const express = require('express');
const { body } = require('express-validator');
const router = express.Router();

const { authenticate, authorize } = require('../../middleware/auth');
const validate = require('../../middleware/validate');
const ctrl = require('./driver.controller');

router.use(authenticate, authorize('driver'));

/**
 * @openapi
 * /driver/profile:
 *   get:
 *     summary: Get the current driver's profile
 *     tags: [Driver]
 *     security: [{ bearerAuth: [] }]
 *   patch:
 *     summary: Update driver profile / documents (resets to pending verification)
 *     tags: [Driver]
 *     security: [{ bearerAuth: [] }]
 */
router.get('/profile', ctrl.getProfileHandler);
router.patch('/profile', ctrl.updateProfileHandler);

/**
 * @openapi
 * /driver/status:
 *   patch:
 *     summary: Toggle online/offline availability and update current location
 *     tags: [Driver]
 *     security: [{ bearerAuth: [] }]
 */
router.patch(
  '/status',
  [
    body('isOnline').isBoolean().withMessage('isOnline must be true or false'),
    body('lat').optional().isFloat({ min: -90, max: 90 }),
    body('lng').optional().isFloat({ min: -180, max: 180 }),
  ],
  validate,
  ctrl.setOnlineHandler
);

router.get('/dashboard', ctrl.dashboardHandler);
router.get('/trips/history', ctrl.historyHandler);
router.get('/reports/earnings', ctrl.earningsHandler);

module.exports = router;
