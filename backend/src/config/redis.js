'use strict';

const { createClient } = require('redis');
const env = require('./env');
const logger = require('../utils/logger');

const redisClient = createClient({
  socket: {
    host: env.redis.host,
    port: env.redis.port,
    tls: env.redis.tls,
    reconnectStrategy: (retries) => Math.min(retries * 100, 3000),
  },
  password: env.redis.password,
});

redisClient.on('error', (err) => {
  logger.error('Redis client error', { error: err.message });
});

redisClient.on('connect', () => {
  logger.info('Redis connected');
});

let connectPromise = null;
function connectRedis() {
  if (!connectPromise) {
    connectPromise = redisClient.connect();
  }
  return connectPromise;
}

/**
 * Cache a JSON-serializable value with a TTL (seconds).
 */
async function cacheSet(key, value, ttlSeconds = 300) {
  await redisClient.set(key, JSON.stringify(value), { EX: ttlSeconds });
}

/**
 * Retrieve and parse a cached JSON value, or null if missing.
 */
async function cacheGet(key) {
  const raw = await redisClient.get(key);
  return raw ? JSON.parse(raw) : null;
}

async function cacheDel(key) {
  await redisClient.del(key);
}

module.exports = {
  redisClient,
  connectRedis,
  cacheSet,
  cacheGet,
  cacheDel,
};
