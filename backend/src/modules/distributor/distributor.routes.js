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

router.get(
  '/shops/by-code',
  [
    queryValidator('code')
      .trim()
      .toUpperCase()
      .matches(/^DL-[A-Z0-9]{6}$/)
      .withMessage('code must look like DL-XXXXXX'),
  ],
  validate,
  ctrl.lookupByCodeHandler
);

router.get('/dashboard', ctrl.dashboardHandler);

router.get('/reports', ctrl.reportsHandler);

module.exports = router;
