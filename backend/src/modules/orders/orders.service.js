'use strict';

const { query } = require('../../config/database');
const ApiError = require('../../utils/ApiError');
const notificationsService = require('../notifications/notifications.service');

async function createOrderRequest(shopkeeperUserId, distributorCode, message) {
  const { rows } = await query(
    `SELECT id, full_name FROM users WHERE user_code = $1 AND role = 'distributor' AND is_active = TRUE`,
    [distributorCode]
  );
  const distributor = rows[0];
  if (!distributor) {
    throw ApiError.notFound('No active distributor found with that code. Double-check the code and try again.');
  }

  const { rows: inserted } = await query(
    `INSERT INTO order_requests (shopkeeper_user_id, distributor_user_id, message, status)
     VALUES ($1, $2, $3, 'pending')
     RETURNING *`,
    [shopkeeperUserId, distributor.id, message]
  );
  const orderRequest = inserted[0];

  const { rows: shopkeeperRows } = await query('SELECT full_name FROM users WHERE id = $1', [
    shopkeeperUserId,
  ]);

  await notificationsService.notifyUser({
    userId: distributor.id,
    title: 'New order request',
    body: `${shopkeeperRows[0]?.full_name || 'A shopkeeper'} sent you an order request: "${message.slice(0, 80)}"`,
  });

  return orderRequest;
}

async function listSentRequests(shopkeeperUserId, { page = 1, limit = 20 } = {}) {
  const offset = (page - 1) * limit;
  const { rows } = await query(
    `SELECT o.*, u.full_name AS distributor_name, u.user_code AS distributor_code
     FROM order_requests o
     JOIN users u ON u.id = o.distributor_user_id
     WHERE o.shopkeeper_user_id = $1
     ORDER BY o.created_at DESC LIMIT $2 OFFSET $3`,
    [shopkeeperUserId, limit, offset]
  );
  return rows;
}

async function listReceivedRequests(distributorUserId, { page = 1, limit = 20, status } = {}) {
  const conditions = ['o.distributor_user_id = $1'];
  const values = [distributorUserId];
  let idx = 2;
  if (status) {
    conditions.push(`o.status = $${idx++}`);
    values.push(status);
  }
  const offset = (page - 1) * limit;
  values.push(limit, offset);

  const { rows } = await query(
    `SELECT o.*, u.full_name AS shopkeeper_name, u.user_code AS shopkeeper_code, u.phone AS shopkeeper_phone
     FROM order_requests o
     JOIN users u ON u.id = o.shopkeeper_user_id
     WHERE ${conditions.join(' AND ')}
     ORDER BY o.created_at DESC LIMIT $${idx} OFFSET $${idx + 1}`,
    values
  );
  return rows;
}

async function updateRequestStatus(distributorUserId, requestId, status) {
  const { rows } = await query(
    `UPDATE order_requests SET status = $1
     WHERE id = $2 AND distributor_user_id = $3
     RETURNING *`,
    [status, requestId, distributorUserId]
  );
  const updated = rows[0];
  if (!updated) throw ApiError.notFound('Order request not found');

  const statusMessages = {
    acknowledged: 'Your order request has been acknowledged by the distributor.',
    fulfilled: 'Your order request has been marked as fulfilled.',
    declined: 'Your order request was declined by the distributor.',
  };

  await notificationsService.notifyUser({
    userId: updated.shopkeeper_user_id,
    title: 'Order request update',
    body: statusMessages[status] || 'Your order request status has changed.',
  });

  return updated;
}

module.exports = { createOrderRequest, listSentRequests, listReceivedRequests, updateRequestStatus };