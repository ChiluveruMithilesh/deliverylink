'use strict';

const ApiError = require('../utils/ApiError');
const logger = require('../utils/logger');
const env = require('../config/env');

/**
 * 404 handler - must be registered after all routes.
 */
function notFoundHandler(req, res, next) {
  next(ApiError.notFound(`Route not found: ${req.method} ${req.originalUrl}`));
}

/**
 * Converts known error types (validation, JWT, Postgres) into ApiError
 * so the final handler always deals with a consistent shape.
 */
function errorConverter(err, req, res, next) {
  let error = err;

  if (!(error instanceof ApiError)) {
    if (error.name === 'JsonWebTokenError') {
      error = ApiError.unauthorized('Invalid authentication token');
    } else if (error.name === 'TokenExpiredError') {
      error = ApiError.unauthorized('Authentication token has expired');
    } else if (error.code === '23505') {
      // Postgres unique_violation
      error = ApiError.conflict('A record with these details already exists');
    } else if (error.code === '23503') {
      // Postgres foreign_key_violation
      error = ApiError.badRequest('Referenced record does not exist');
    } else if (error.code === '23514') {
      // Postgres check_violation
      error = ApiError.badRequest('Value violates a database constraint');
    } else {
      const statusCode = error.statusCode || 500;
      error = new ApiError(statusCode, error.message || 'Internal server error', [], false);
    }
  }

  next(error);
}

/**
 * Final error handler - formats and sends the HTTP response.
 * Never leaks stack traces or internal details in production.
 */
function errorHandler(err, req, res, next) { // eslint-disable-line no-unused-vars
  const { statusCode = 500, message, details, isOperational } = err;

  if (!isOperational || statusCode >= 500) {
    logger.error('Unhandled/internal error', {
      message: err.message,
      stack: err.stack,
      path: req.originalUrl,
      method: req.method,
      userId: req.user?.id,
    });
  } else {
    logger.warn('Operational error', {
      message: err.message,
      statusCode,
      path: req.originalUrl,
    });
  }

  const responseBody = {
    success: false,
    error: {
      message: statusCode >= 500 && env.nodeEnv === 'production' ? 'Internal server error' : message,
      details: details && details.length ? details : undefined,
    },
  };

  if (env.nodeEnv !== 'production') {
    responseBody.error.stack = err.stack;
  }

  res.status(statusCode).json(responseBody);
}

module.exports = { notFoundHandler, errorConverter, errorHandler };
