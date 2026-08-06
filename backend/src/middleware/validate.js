'use strict';

const { validationResult } = require('express-validator');
const ApiError = require('../utils/ApiError');

/**
 * Runs after express-validator rule chains; collects any failures
 * into a single 400 ApiError with field-level details.
 */
function validate(req, res, next) {
  const errors = validationResult(req);
  if (errors.isEmpty()) return next();

  const details = errors.array().map((e) => ({ field: e.path, message: e.msg }));
  throw ApiError.badRequest('Validation failed', details);
}

module.exports = validate;
