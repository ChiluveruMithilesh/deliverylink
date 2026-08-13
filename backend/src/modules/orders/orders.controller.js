'use strict';

const ordersService = require('./orders.service');

async function createHandler(req, res) {
  const { distributorCode, message } = req.body;
  const orderRequest = await ordersService.createOrderRequest(req.user.id, distributorCode, message);
  res.status(201).json({ success: true, data: orderRequest });
}

async function listSentHandler(req, res) {
  const { page, limit } = req.query;
  const requests = await ordersService.listSentRequests(req.user.id, {
    page: parseInt(page, 10) || 1,
    limit: Math.min(parseInt(limit, 10) || 20, 100),
  });
  res.json({ success: true, data: requests });
}

async function listReceivedHandler(req, res) {
  const { page, limit, status } = req.query;
  const requests = await ordersService.listReceivedRequests(req.user.id, {
    page: parseInt(page, 10) || 1,
    limit: Math.min(parseInt(limit, 10) || 20, 100),
    status,
  });
  res.json({ success: true, data: requests });
}

async function updateStatusHandler(req, res) {
  const updated = await ordersService.updateRequestStatus(req.user.id, req.params.id, req.body.status);
  res.json({ success: true, data: updated });
}

module.exports = { createHandler, listSentHandler, listReceivedHandler, updateStatusHandler };