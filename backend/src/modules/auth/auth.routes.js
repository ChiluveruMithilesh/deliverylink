'use strict';

const express = require('express');
const router = express.Router();

const { registerValidator, loginValidator, refreshValidator, updateProfileValidator } = require('./auth.validators');
const validate = require('../../middleware/validate');
const { authenticate } = require('../../middleware/auth');
const { authLimiter } = require('../../middleware/rateLimiter');
const {
  registerHandler,
  loginHandler,
  refreshHandler,
  meHandler,
  updateMeHandler,
} = require('./auth.controller');

/**
 * @openapi
 * /auth/register:
 *   post:
 *     summary: Register a new distributor, driver, or shopkeeper
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *     responses:
 *       201:
 *         description: Account created, returns user + tokens
 *       409:
 *         description: Phone number already registered
 */
router.post('/register', authLimiter, registerValidator, validate, registerHandler);

/**
 * @openapi
 * /auth/login:
 *   post:
 *     summary: Log in with phone number and password
 *     tags: [Auth]
 *     responses:
 *       200:
 *         description: Returns user + tokens
 *       401:
 *         description: Invalid credentials
 */
router.post('/login', authLimiter, loginValidator, validate, loginHandler);

/**
 * @openapi
 * /auth/refresh:
 *   post:
 *     summary: Exchange a valid refresh token for a new access/refresh token pair
 *     tags: [Auth]
 *     responses:
 *       200:
 *         description: New token pair issued
 *       401:
 *         description: Invalid or expired refresh token
 */
router.post('/refresh', authLimiter, refreshValidator, validate, refreshHandler);

/**
 * @openapi
 * /auth/me:
 *   get:
 *     summary: Get the currently authenticated user's profile
 *     tags: [Auth]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Current user
 *       401:
 *         description: Not authenticated
 */
router.get('/me', authenticate, meHandler);
router.patch('/me', authenticate, updateProfileValidator, validate, updateMeHandler);

module.exports = router;
