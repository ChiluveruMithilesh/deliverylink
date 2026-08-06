'use strict';

const adminService = require('./admin.service');

async function listUsersHandler(req, res) {
  const { role, search, page, limit } = req.query;
  const users = await adminService.listUsers({
    role,
    search,
    page: parseInt(page, 10) || 1,
    limit: Math.min(parseInt(limit, 10) || 20, 100),
  });
  res.json({ success: true, data: users });
}

async function setUserActiveHandler(req, res) {
  const user = await adminService.setUserActive(req.params.id, req.body.isActive);
  res.json({ success: true, data: user });
}

async function listPendingDriversHandler(req, res) {
  const drivers = await adminService.listPendingDrivers();
  res.json({ success: true, data: drivers });
}

async function reviewDriverHandler(req, res) {
  const driver = await adminService.reviewDriver(req.params.id, req.body.decision);
  res.json({ success: true, data: driver });
}

async function listAllTripsHandler(req, res) {
  const { status, page, limit } = req.query;
  const trips = await adminService.listAllTrips({
    status,
    page: parseInt(page, 10) || 1,
    limit: Math.min(parseInt(limit, 10) || 20, 100),
  });
  res.json({ success: true, data: trips });
}

async function analyticsHandler(req, res) {
  const analytics = await adminService.getPlatformAnalytics();
  res.json({ success: true, data: analytics });
}

async function listPricingRulesHandler(req, res) {
  const rules = await adminService.listPricingRules();
  res.json({ success: true, data: rules });
}

async function createPricingRuleHandler(req, res) {
  const rule = await adminService.createPricingRule(req.body);
  res.status(201).json({ success: true, data: rule });
}

async function togglePricingRuleHandler(req, res) {
  const rule = await adminService.togglePricingRule(req.params.id, req.body.isActive);
  res.json({ success: true, data: rule });
}

module.exports = {
  listUsersHandler,
  setUserActiveHandler,
  listPendingDriversHandler,
  reviewDriverHandler,
  listAllTripsHandler,
  analyticsHandler,
  listPricingRulesHandler,
  createPricingRuleHandler,
  togglePricingRuleHandler,
};
