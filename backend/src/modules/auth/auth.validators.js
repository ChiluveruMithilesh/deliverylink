'use strict';

const { body } = require('express-validator');

const registerValidator = [
  body('role')
    .isIn(['distributor', 'driver', 'shopkeeper'])
    .withMessage('role must be one of distributor, driver, shopkeeper'),
  body('fullName').trim().isLength({ min: 2, max: 120 }).withMessage('fullName is required (2-120 chars)'),
  body('phone')
    .trim()
    .matches(/^[6-9]\d{9}$/)
    .withMessage('phone must be a valid 10-digit Indian mobile number'),
  body('password')
    .isLength({ min: 8 })
    .withMessage('password must be at least 8 characters')
    .matches(/\d/)
    .withMessage('password must contain at least one number'),
  body('email').optional().isEmail().withMessage('email must be valid'),
  body('preferredLanguage').optional().isIn(['en', 'te']).withMessage('preferredLanguage must be en or te'),

  // Role-specific fields, validated conditionally
  body('businessName')
    .if(body('role').equals('distributor'))
    .trim()
    .notEmpty()
    .withMessage('businessName is required for distributors'),

  body('vehicleType')
    .if(body('role').equals('driver'))
    .isIn(['auto', 'mini_truck', 'pickup', 'tempo'])
    .withMessage('vehicleType is required for drivers'),
  body('vehicleNumber')
    .if(body('role').equals('driver'))
    .trim()
    .notEmpty()
    .withMessage('vehicleNumber is required for drivers'),
  body('drivingLicenceNumber')
    .if(body('role').equals('driver'))
    .trim()
    .notEmpty()
    .withMessage('drivingLicenceNumber is required for drivers'),
  body('vehicleCapacityKg')
    .if(body('role').equals('driver'))
    .isFloat({ gt: 0 })
    .withMessage('vehicleCapacityKg must be a positive number for drivers'),

  body('shopName')
    .if(body('role').equals('shopkeeper'))
    .trim()
    .notEmpty()
    .withMessage('shopName is required for shopkeepers'),
  body('shopAddress')
    .if(body('role').equals('shopkeeper'))
    .trim()
    .notEmpty()
    .withMessage('shopAddress is required for shopkeepers'),
  body('shopLat').if(body('role').equals('shopkeeper')).isFloat().withMessage('shopLat is required'),
  body('shopLng').if(body('role').equals('shopkeeper')).isFloat().withMessage('shopLng is required'),
];

const loginValidator = [
  body('phone')
    .trim()
    .matches(/^[6-9]\d{9}$/)
    .withMessage('phone must be a valid 10-digit Indian mobile number'),
  body('password').notEmpty().withMessage('password is required'),
];

const refreshValidator = [body('refreshToken').notEmpty().withMessage('refreshToken is required')];

module.exports = { registerValidator, loginValidator, refreshValidator };
