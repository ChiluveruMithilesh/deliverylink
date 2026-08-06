'use strict';

const express = require('express');
const { body, param } = require('express-validator');
const router = express.Router();

const { authenticate, authorize } = require('../../middleware/auth');
const validate = require('../../middleware/validate');
const ctrl = require('./admin.controller');

router.use(authenticate, authorize('admin'));

/**
 * @openapi
 * /admin/users:
 *   get:
 *     summary: List/search all users, filterable by role
 *     tags: [Admin]
 *     security: [{ bearerAuth: [] }]
 */
router.get('/users', ctrl.listUsersHandler);
router.patch(
  '/users/:id/active',
  [param('id').isUUID(), body('isActive').isBoolean()],
  validate,
  ctrl.setUserActiveHandler
);

/**
 * @openapi
 * /admin/drivers/pending:
 *   get:
 *     summary: List drivers awaiting document verification
 *     tags: [Admin]
 *     security: [{ bearerAuth: [] }]
 */
router.get('/drivers/pending', ctrl.listPendingDriversHandler);
router.patch(
  '/drivers/:id/review',
  [param('id').isUUID(), body('decision').isIn(['approved', 'rejected'])],
  validate,
  ctrl.reviewDriverHandler
);

router.get('/trips', ctrl.listAllTripsHandler);
router.get('/analytics', ctrl.analyticsHandler);

router.get('/pricing-rules', ctrl.listPricingRulesHandler);
router.post(
  '/pricing-rules',
  [
    body('name').trim().notEmpty(),
    body('minDistanceKm').isFloat({ min: 0 }),
    body('maxDistanceKm').isFloat({ min: 0 }),
    body('baseFare').isFloat({ min: 0 }),
    body('perKmRate').isFloat({ min: 0 }),
    body('perStopRate').isFloat({ min: 0 }),
  ],
  validate,
  ctrl.createPricingRuleHandler
);
router.patch(
  '/pricing-rules/:id',
  [param('id').isUUID(), body('isActive').isBoolean()],
  validate,
  ctrl.togglePricingRuleHandler
);

module.exports = router;
