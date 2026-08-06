'use strict';

const { query } = require('../../config/database');
const { initFirebase } = require('../../config/firebase');
const logger = require('../../utils/logger');

/**
 * Creates an in-app notification row and, if the recipient has
 * registered device tokens, sends a push via FCM. Push failures
 * never block the in-app notification from being saved.
 */
async function notifyUser({ userId, tripId = null, title, body, channel = 'push' }) {
  const { rows } = await query(
    `INSERT INTO notifications (user_id, trip_id, title, body, channel, status)
     VALUES ($1, $2, $3, $4, $5, 'queued')
     RETURNING id`,
    [userId, tripId, title, body, channel]
  );
  const notificationId = rows[0].id;

  try {
    await sendPush(userId, title, body, tripId);
    await query(`UPDATE notifications SET status = 'sent' WHERE id = $1`, [notificationId]);
  } catch (err) {
    logger.error('Push notification failed', { userId, error: err.message });
    await query(`UPDATE notifications SET status = 'failed' WHERE id = $1`, [notificationId]);
  }

  return notificationId;
}

async function sendPush(userId, title, body, tripId) {
  const admin = initFirebase();
  if (!admin) return; // Firebase not configured (e.g. local dev) - in-app notification still saved.

  const { rows } = await query('SELECT fcm_token FROM device_tokens WHERE user_id = $1', [userId]);
  if (rows.length === 0) return;

  const tokens = rows.map((r) => r.fcm_token);
  await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: tripId ? { tripId: String(tripId) } : {},
  });
}

async function registerDeviceToken(userId, fcmToken, platform) {
  await query(
    `INSERT INTO device_tokens (user_id, fcm_token, platform)
     VALUES ($1, $2, $3)
     ON CONFLICT (user_id, fcm_token) DO NOTHING`,
    [userId, fcmToken, platform]
  );
}

async function listNotifications(userId, { page = 1, limit = 20 } = {}) {
  const offset = (page - 1) * limit;
  const { rows } = await query(
    `SELECT id, trip_id, title, body, channel, status, read_at, created_at
     FROM notifications WHERE user_id = $1
     ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
    [userId, limit, offset]
  );
  return rows;
}

async function markAsRead(userId, notificationId) {
  await query(
    `UPDATE notifications SET status = 'read', read_at = now()
     WHERE id = $1 AND user_id = $2`,
    [notificationId, userId]
  );
}

module.exports = { notifyUser, registerDeviceToken, listNotifications, markAsRead };
