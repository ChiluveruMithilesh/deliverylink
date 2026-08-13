'use strict';

const { body, param } = require('express-validator');

const createOrderRequestValidator = [
  body('distributorCode')
    .trim()
    .toUpperCase()
    .matches(/^DL-[A-Z0-9]{6}$/)
    .withMessage('distributorCode must look like DL-XXXXXX'),
  body('message')
    .trim()
    .isLength({ min: 1, max: 1000 })
    .withMessage('message is required (max 1000 characters)'),
];

const updateStatusValidator = [
  param('id').isUUID(),
  body('status')
    .isIn(['acknowledged', 'fulfilled', 'declined'])
    .withMessage('status must be acknowledged, fulfilled, or declined'),
];

module.exports = { createOrderRequestValidator, updateStatusValidator };