'use strict';

const distributorService = require('./distributor.service');

async function searchShopsHandler(req, res) {
  const { q, lat, lng } = req.query;
  const shops = await distributorService.searchShops(
    q,
    lat ? parseFloat(lat) : null,
    lng ? parseFloat(lng) : null
  );
  res.json({ success: true, data: shops });
}

async function lookupByCodeHandler(req, res) {
  const { code } = req.query;
  const result = await distributorService.lookupShopsByCode(code.trim().toUpperCase());
  res.json({ success: true, data: result });
}

async function dashboardHandler(req, res) {
  const dashboard = await distributorService.getDashboard(req.user.id);
  res.json({ success: true, data: dashboard });
}

async function reportsHandler(req, res) {
  const { fromDate, toDate } = req.query;
  const reports = await distributorService.getReports(req.user.id, { fromDate, toDate });
  res.json({ success: true, data: reports });
}

module.exports = { searchShopsHandler, lookupByCodeHandler, dashboardHandler, reportsHandler };
