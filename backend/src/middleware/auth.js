'use strict';

const { verifyAccessToken } = require('../utils/jwt');
const ApiError = require('../utils/ApiError');
const { query } = require('../config/database');

/**
 * Verifies the Bearer JWT, loads a minimal user record, and attaches
 * it to req.user. Rejects if the user was deactivated after token issue.
 */
async function authenticate(req, res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');

  if (scheme !== 'Bearer' || !token) {
    throw ApiError.unauthorized('Missing or malformed Authorization header');
  }

  let payload;
  try {
    payload = verifyAccessToken(token);
  } catch (err) {
    throw ApiError.unauthorized('Invalid or expired access token');
  }

  if (payload.type !== 'access') {
    throw ApiError.unauthorized('Token is not a valid access token');
  }

  const { rows } = await query(
    'SELECT id, role, full_name, phone, is_active FROM users WHERE id = $1',
    [payload.sub]
  );

  const user = rows[0];
  if (!user || !user.is_active) {
    throw ApiError.unauthorized('Account is inactive or no longer exists');
  }

  req.user = { id: user.id, role: user.role, fullName: user.full_name, phone: user.phone };
  next();
}

/**
 * Restricts a route to one or more roles.
 * Usage: router.get('/x', authenticate, authorize('distributor', 'admin'), handler)
 */
function authorize(...allowedRoles) {
  return (req, res, next) => {
    if (!req.user) {
      throw ApiError.unauthorized('Authentication required');
    }
    if (!allowedRoles.includes(req.user.role)) {
      throw ApiError.forbidden('You do not have permission to perform this action');
    }
    next();
  };
}

module.exports = { authenticate, authorize };
