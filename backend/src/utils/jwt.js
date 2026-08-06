'use strict';

const jwt = require('jsonwebtoken');
const env = require('../config/env');

/**
 * @param {{id: string, role: string}} user
 */
function signAccessToken(user) {
  return jwt.sign({ sub: user.id, role: user.role, type: 'access' }, env.jwt.accessSecret, {
    expiresIn: env.jwt.accessExpiry,
  });
}

/**
 * @param {{id: string, role: string}} user
 */
function signRefreshToken(user) {
  return jwt.sign({ sub: user.id, role: user.role, type: 'refresh' }, env.jwt.refreshSecret, {
    expiresIn: env.jwt.refreshExpiry,
  });
}

function verifyAccessToken(token) {
  return jwt.verify(token, env.jwt.accessSecret);
}

function verifyRefreshToken(token) {
  return jwt.verify(token, env.jwt.refreshSecret);
}

module.exports = { signAccessToken, signRefreshToken, verifyAccessToken, verifyRefreshToken };
