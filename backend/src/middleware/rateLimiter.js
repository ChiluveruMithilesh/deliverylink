'use strict';

const rateLimit = require('express-rate-limit');
const env = require('../config/env');
const ApiError = require('../utils/ApiError');

/**
 * General API rate limiter - applied globally.
 */
const generalLimiter = rateLimit({
  windowMs: env.rateLimit.windowMs,
  max: env.rateLimit.maxRequests,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res, next) => {
    next(new ApiError(429, 'Too many requests, please try again later'));
  },
});

/**
 * Stricter limiter for auth endpoints (login, OTP, register)
 * to slow down credential-stuffing and brute force attempts.
 */
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res, next) => {
    next(new ApiError(429, 'Too many authentication attempts. Please try again in 15 minutes.'));
  },
});

/**
 * Relaxed limiter for high-frequency, low-risk endpoints
 * like live GPS location pings.
 */
const locationPingLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 60, // up to once per second
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res, next) => {
    next(new ApiError(429, 'Location updates are being sent too frequently'));
  },
});

module.exports = { generalLimiter, authLimiter, locationPingLimiter };
