'use strict';

const notificationsService = require('./notifications.service');

async function listHandler(req, res) {
  const page = parseInt(req.query.page, 10) || 1;
  const limit = Math.min(parseInt(req.query.limit, 10) || 20, 100);
  const notifications = await notificationsService.listNotifications(req.user.id, { page, limit });
  res.json({ success: true, data: notifications, meta: { page, limit } });
}

async function markReadHandler(req, res) {
  await notificationsService.markAsRead(req.user.id, req.params.id);
  res.json({ success: true, data: { id: req.params.id, status: 'read' } });
}

async function registerTokenHandler(req, res) {
  const { fcmToken, platform } = req.body;
  await notificationsService.registerDeviceToken(req.user.id, fcmToken, platform);
  res.status(201).json({ success: true, data: { registered: true } });
}

module.exports = { listHandler, markReadHandler, registerTokenHandler };
