'use strict';

const driverService = require('./driver.service');

async function getProfileHandler(req, res) {
  const profile = await driverService.getProfile(req.user.id);
  res.json({ success: true, data: profile });
}

async function updateProfileHandler(req, res) {
  const profile = await driverService.updateProfile(req.user.id, req.body);
  res.json({ success: true, data: profile });
}

async function setOnlineHandler(req, res) {
  const { isOnline, lat, lng } = req.body;
  const profile = await driverService.setOnlineStatus(req.user.id, isOnline, lat, lng);
  res.json({ success: true, data: profile });
}

async function dashboardHandler(req, res) {
  const dashboard = await driverService.getDashboard(req.user.id);
  res.json({ success: true, data: dashboard });
}

async function historyHandler(req, res) {
  const { page, limit } = req.query;
  const trips = await driverService.getTripHistory(req.user.id, {
    page: parseInt(page, 10) || 1,
    limit: Math.min(parseInt(limit, 10) || 20, 100),
  });
  res.json({ success: true, data: trips });
}

async function earningsHandler(req, res) {
  const { fromDate, toDate } = req.query;
  const report = await driverService.getEarningsReport(req.user.id, { fromDate, toDate });
  res.json({ success: true, data: report });
}

module.exports = {
  getProfileHandler,
  updateProfileHandler,
  setOnlineHandler,
  dashboardHandler,
  historyHandler,
  earningsHandler,
};
