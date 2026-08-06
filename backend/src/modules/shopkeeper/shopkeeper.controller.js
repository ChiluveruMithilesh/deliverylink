'use strict';

const shopkeeperService = require('./shopkeeper.service');

async function listShopsHandler(req, res) {
  const shops = await shopkeeperService.listMyShops(req.user.id);
  res.json({ success: true, data: shops });
}

async function addShopHandler(req, res) {
  const shop = await shopkeeperService.addShop(req.user.id, req.body);
  res.status(201).json({ success: true, data: shop });
}

async function updateShopHandler(req, res) {
  const shop = await shopkeeperService.updateShop(req.user.id, req.params.id, req.body);
  res.json({ success: true, data: shop });
}

async function todaysDeliveriesHandler(req, res) {
  const deliveries = await shopkeeperService.getTodaysDeliveries(req.user.id);
  res.json({ success: true, data: deliveries });
}

async function historyHandler(req, res) {
  const { page, limit } = req.query;
  const history = await shopkeeperService.getDeliveryHistory(req.user.id, {
    page: parseInt(page, 10) || 1,
    limit: Math.min(parseInt(limit, 10) || 20, 100),
  });
  res.json({ success: true, data: history });
}

module.exports = { listShopsHandler, addShopHandler, updateShopHandler, todaysDeliveriesHandler, historyHandler };
