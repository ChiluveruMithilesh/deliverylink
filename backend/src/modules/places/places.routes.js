'use strict';

const express = require('express');
const { query: queryValidator } = require('express-validator');
const router = express.Router();

const { authenticate } = require('../../middleware/auth');
const validate = require('../../middleware/validate');
const ctrl = require('./places.controller');

router.use(authenticate);

router.get(
  '/autocomplete',
  [
    queryValidator('query').trim().isLength({ min: 2 }).withMessage('query must be at least 2 characters'),
    queryValidator('lat').optional().isFloat({ min: -90, max: 90 }),
    queryValidator('lng').optional().isFloat({ min: -180, max: 180 }),
  ],
  validate,
  ctrl.autocompleteHandler
);

router.get(
  '/details',
  [queryValidator('placeId').trim().notEmpty().withMessage('placeId is required')],
  validate,
  ctrl.detailsHandler
);

module.exports = router;