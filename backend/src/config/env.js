'use strict';

require('dotenv').config();

/**
 * Centralized, validated environment configuration.
 * Fails fast at boot if a required variable is missing,
 * rather than surfacing cryptic errors deep in the app.
 */
const REQUIRED_IN_PRODUCTION = [
  'DB_HOST',
  'DB_NAME',
  'DB_USER',
  'DB_PASSWORD',
  'JWT_ACCESS_SECRET',
  'JWT_REFRESH_SECRET',
];

const env = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT, 10) || 4000,
  apiBaseUrl: process.env.API_BASE_URL || 'http://localhost:4000',

  db: {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT, 10) || 5432,
    name: process.env.DB_NAME || 'deliverylink',
    user: process.env.DB_USER || 'deliverylink_app',
    password: process.env.DB_PASSWORD || '',
    poolMax: parseInt(process.env.DB_POOL_MAX, 10) || 20,
    ssl: process.env.DB_SSL === 'true',
  },

  redis: {
    host: process.env.REDIS_HOST || 'localhost',
    port: parseInt(process.env.REDIS_PORT, 10) || 6379,
    password: process.env.REDIS_PASSWORD || undefined,
    tls: process.env.REDIS_TLS === 'true',
  },

  jwt: {
    accessSecret: process.env.JWT_ACCESS_SECRET || 'dev-only-insecure-access-secret',
    refreshSecret: process.env.JWT_REFRESH_SECRET || 'dev-only-insecure-refresh-secret',
    accessExpiry: process.env.JWT_ACCESS_EXPIRY || '15m',
    refreshExpiry: process.env.JWT_REFRESH_EXPIRY || '30d',
  },

  firebase: {
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: (process.env.FIREBASE_PRIVATE_KEY || '').replace(/\\n/g, '\n'),
    storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
  },

  googleMaps: {
    mapsApiKey: process.env.GOOGLE_MAPS_API_KEY,
    directionsApiKey: process.env.GOOGLE_DIRECTIONS_API_KEY,
    distanceMatrixApiKey: process.env.GOOGLE_DISTANCE_MATRIX_API_KEY,
  },

  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS, 10) || 60000,
    maxRequests: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS, 10) || 100,
  },

  uploads: {
    maxSizeMb: parseInt(process.env.MAX_UPLOAD_SIZE_MB, 10) || 10,
    tempDir: process.env.UPLOAD_TEMP_DIR || './tmp/uploads',
  },

  logLevel: process.env.LOG_LEVEL || 'info',
};

function validateEnv() {
  if (env.nodeEnv !== 'production') return;
  const missing = REQUIRED_IN_PRODUCTION.filter((key) => !process.env[key]);
  if (missing.length > 0) {
    throw new Error(
      `Missing required environment variables in production: ${missing.join(', ')}`
    );
  }
}

validateEnv();

module.exports = env;
