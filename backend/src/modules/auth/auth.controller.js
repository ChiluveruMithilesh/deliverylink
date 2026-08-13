'use strict';

const authService = require('./auth.service');

async function registerHandler(req, res) {
  const result = await authService.register(req.body);
  res.status(201).json({
    success: true,
    data: {
      user: result.user,
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    },
  });
}

async function loginHandler(req, res) {
  const { phone, password } = req.body;
  const result = await authService.login(phone, password);
  res.status(200).json({ success: true, data: result });
}

async function refreshHandler(req, res) {
  const { refreshToken } = req.body;
  const result = await authService.refresh(refreshToken);
  res.status(200).json({ success: true, data: result });
}
async function meHandler(req, res) {
  const profile = await authService.getProfile(req.user.id);
  res.status(200).json({ success: true, data: { user: profile } });
}

async function updateMeHandler(req, res) {
  const profile = await authService.updateProfile(req.user.id, req.body);
  res.status(200).json({ success: true, data: { user: profile } });
}

module.exports = { registerHandler, loginHandler, refreshHandler, meHandler, updateMeHandler };