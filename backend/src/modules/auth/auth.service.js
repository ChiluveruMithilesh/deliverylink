'use strict';

const bcrypt = require('bcryptjs');
const { withTransaction, query } = require('../../config/database');
const { signAccessToken, signRefreshToken, verifyRefreshToken } = require('../../utils/jwt');
const { generateUniqueUserCode } = require('../../utils/userCode');
const ApiError = require('../../utils/ApiError');
const logger = require('../../utils/logger');

const SALT_ROUNDS = 12;

/**
 * Registers a new user and their role-specific profile row
 * in a single transaction so partial records can never be created.
 */
async function register(payload) {
  const { role, fullName, phone, password, email, preferredLanguage } = payload;

  const existing = await query('SELECT id FROM users WHERE phone = $1', [phone]);
  if (existing.rows.length > 0) {
    throw ApiError.conflict('An account with this phone number already exists');
  }

  const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);
  const userCode = await generateUniqueUserCode();

  return withTransaction(async (client) => {
    const userResult = await client.query(
      `INSERT INTO users (role, full_name, phone, email, password_hash, preferred_language, user_code)
       VALUES ($1, $2, $3, $4, $5, COALESCE($6, 'en'), $7)
       RETURNING id, role, full_name, phone, email, preferred_language, user_code, created_at`,
      [role, fullName, phone, email || null, passwordHash, preferredLanguage, userCode]
    );
    const user = userResult.rows[0];

    if (role === 'distributor') {
      await client.query(
        `INSERT INTO distributors (user_id, business_name) VALUES ($1, $2)`,
        [user.id, payload.businessName]
      );
    } else if (role === 'driver') {
      await client.query(
        `INSERT INTO drivers
           (user_id, driving_licence_number, vehicle_type, vehicle_number, vehicle_capacity_kg, aadhaar_number)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [
          user.id,
          payload.drivingLicenceNumber,
          payload.vehicleType,
          payload.vehicleNumber,
          payload.vehicleCapacityKg,
          payload.aadhaarNumber || null,
        ]
      );
    } else if (role === 'shopkeeper') {
      await client.query(
        `INSERT INTO shops (shopkeeper_user_id, shop_name, contact_number, address, lat, lng)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [user.id, payload.shopName, phone, payload.shopAddress, payload.shopLat, payload.shopLng]
      );
    }

    const accessToken = signAccessToken(user);
    const refreshToken = signRefreshToken(user);

    logger.info('User registered', { userId: user.id, role: user.role });

    return { user, accessToken, refreshToken };
  });
}

async function login(phone, password) {
  const { rows } = await query(
    'SELECT id, role, full_name, phone, email, preferred_language, user_code, password_hash, is_active FROM users WHERE phone = $1',
    [phone]
  );
  const user = rows[0];

  // Compare against a dummy hash even when the user doesn't exist,
  // so response timing doesn't reveal whether a phone number is registered.
  const hashToCompare = user?.password_hash || '$2a$12$invalidinvalidinvalidinvalidinvalidinvalidinvalid';
  const passwordMatches = await bcrypt.compare(password, hashToCompare);

  if (!user || !passwordMatches) {
    throw ApiError.unauthorized('Invalid phone number or password');
  }
  if (!user.is_active) {
    throw ApiError.forbidden('This account has been deactivated');
  }

  await query('UPDATE users SET last_login_at = now() WHERE id = $1', [user.id]);

  const accessToken = signAccessToken(user);
  const refreshToken = signRefreshToken(user);

  return {
    user: {
      id: user.id,
      role: user.role,
      fullName: user.full_name,
      phone: user.phone,
      email: user.email,
      preferredLanguage: user.preferred_language,
      userCode: user.user_code,
    },
    accessToken,
    refreshToken,
  };
}

async function refresh(refreshToken) {
  let payload;
  try {
    payload = verifyRefreshToken(refreshToken);
  } catch (err) {
    throw ApiError.unauthorized('Invalid or expired refresh token');
  }
  if (payload.type !== 'refresh') {
    throw ApiError.unauthorized('Token is not a valid refresh token');
  }

  const { rows } = await query('SELECT id, role, is_active FROM users WHERE id = $1', [payload.sub]);
  const user = rows[0];
  if (!user || !user.is_active) {
    throw ApiError.unauthorized('Account is inactive or no longer exists');
  }

  return {
    accessToken: signAccessToken(user),
    refreshToken: signRefreshToken(user),
  };
}

async function getProfile(userId) {
  const { rows } = await query(
    `SELECT id, role, full_name, phone, email, preferred_language, user_code, created_at
     FROM users WHERE id = $1`,
    [userId]
  );
  if (!rows[0]) throw ApiError.notFound('User not found');
  return rows[0];
}

async function updateProfile(userId, payload) {
  const fields = [];
  const values = [];
  let idx = 1;

  if (payload.fullName !== undefined) {
    fields.push(`full_name = $${idx++}`);
    values.push(payload.fullName);
  }
  if (payload.email !== undefined) {
    fields.push(`email = $${idx++}`);
    values.push(payload.email);
  }
  if (payload.preferredLanguage !== undefined) {
    fields.push(`preferred_language = $${idx++}`);
    values.push(payload.preferredLanguage);
  }

  if (fields.length === 0) return getProfile(userId);

  values.push(userId);
  await query(`UPDATE users SET ${fields.join(', ')} WHERE id = $${idx}`, values);
  return getProfile(userId);
}

module.exports = { register, login, refresh, getProfile, updateProfile };
