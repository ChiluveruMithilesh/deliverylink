'use strict';

const logger = require('../utils/logger');

/**
 * Lightweight structured request logger.
 * Logs method, path, status, duration and user id (if authenticated).
 */
function requestLogger(req, res, next) {
  const start = Date.now();

  res.on('finish', () => {
    const duration = Date.now() - start;
    const level = res.statusCode >= 500 ? 'error' : res.statusCode >= 400 ? 'warn' : 'info';

    logger.log(level, 'HTTP request', {
      method: req.method,
      path: req.originalUrl,
      statusCode: res.statusCode,
      durationMs: duration,
      userId: req.user?.id,
      ip: req.ip,
    });
  });

  next();
}

module.exports = requestLogger;
