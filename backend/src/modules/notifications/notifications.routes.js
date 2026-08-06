'use strict';

const express = require('express');
const { body } = require('express-validator');
const router = express.Router();

const { authenticate } = require('../../middleware/auth');
const validate = require('../../middleware/validate');
const { listHandler, markReadHandler, registerTokenHandler } = require('./notifications.controller');

router.use(authenticate);

/**
 * @openapi
 * /notifications:
 *   get:
 *     summary: List the current user's notifications (paginated)
 *     tags: [Notifications]
 *     security: [{ bearerAuth: [] }]
 */
router.get('/', listHandler);

/**
 * @openapi
 * /notifications/{id}/read:
 *   patch:
 *     summary: Mark a notification as read
 *     tags: [Notifications]
 *     security: [{ bearerAuth: [] }]
 */
router.patch('/:id/read', markReadHandler);

/**
 * @openapi
 * /notifications/device-token:
 *   post:
 *     summary: Register an FCM device token for push notifications
 *     tags: [Notifications]
 *     security: [{ bearerAuth: [] }]
 */
router.post(
  '/device-token',
  [
    body('fcmToken').notEmpty().withMessage('fcmToken is required'),
    body('platform').isIn(['android', 'ios', 'web']).withMessage('platform must be android, ios, or web'),
  ],
  validate,
  registerTokenHandler
);

module.exports = router;
