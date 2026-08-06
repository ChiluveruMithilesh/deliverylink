'use strict';

const express = require('express');
const { query: queryValidator } = require('express-validator');
const router = express.Router();

const { authenticate, authorize } = require('../../middleware/auth');
const validate = require('../../middleware/validate');
const ctrl = require('./distributor.controller');

router.use(authenticate, authorize('distributor'));

/**
 * @openapi
 * /distributor/shops/search:
 *   get:
 *     summary: Search registered shops by name when building a trip
 *     tags: [Distributor]
 *     security: [{ bearerAuth: [] }]
 */
router.get(
  '/shops/search',
  [queryValidator('q').trim().notEmpty().withMessage('q (search term) is required')],
  validate,
  ctrl.searchShopsHandler
);

router.get('/dashboard', ctrl.dashboardHandler);
router.get('/reports', ctrl.reportsHandler);

module.exports = router;
