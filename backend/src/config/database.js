'use strict';

const { Pool } = require('pg');
const env = require('./env');
const logger = require('../utils/logger');

const pool = new Pool({
  host: env.db.host,
  port: env.db.port,
  database: env.db.name,
  user: env.db.user,
  password: env.db.password,
  max: env.db.poolMax,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
  ssl: env.db.ssl ? { rejectUnauthorized: false } : false,
});

pool.on('error', (err) => {
  // Idle client errors should never crash the whole process.
  logger.error('Unexpected PostgreSQL pool error', { error: err.message });
});

/**
 * Run a single query using the shared pool.
 * @param {string} text - SQL query text with $1, $2 placeholders.
 * @param {Array} params - Query parameters.
 */
async function query(text, params = []) {
  const start = Date.now();
  const result = await pool.query(text, params);
  const duration = Date.now() - start;
  if (duration > 200) {
    logger.warn('Slow query detected', { text, duration, rows: result.rowCount });
  }
  return result;
}

/**
 * Acquire a client for multi-statement transactions.
 * Caller MUST release the client in a finally block.
 */
async function getClient() {
  const client = await pool.connect();
  const originalRelease = client.release.bind(client);
  client.release = () => {
    client.release = originalRelease;
    return originalRelease();
  };
  return client;
}

/**
 * Run a callback inside a transaction, committing on success
 * and rolling back automatically on any thrown error.
 * @param {(client: import('pg').PoolClient) => Promise<any>} callback
 */
async function withTransaction(callback) {
  const client = await getClient();
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function checkConnection() {
  const result = await query('SELECT NOW() AS now');
  return result.rows[0].now;
}

module.exports = {
  pool,
  query,
  getClient,
  withTransaction,
  checkConnection,
};
