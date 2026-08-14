'use strict';

/**
 * One-time backfill: assigns a unique user_code to any account created
 * before the user-code feature existed. Safe to run multiple times -
 * only touches rows where user_code IS NULL, so already-coded users
 * (including anyone registered after this feature shipped) are untouched.
 *
 * Usage: node src/db/backfillUserCodes.js
 */

const { pool, query } = require('../config/database');
const { generateUniqueUserCode } = require('../utils/userCode');
const logger = require('../utils/logger');

async function backfillUserCodes() {
  const { rows } = await query('SELECT id, full_name, phone FROM users WHERE user_code IS NULL');

  if (rows.length === 0) {
    logger.info('No users need a backfilled code. All accounts already have one.');
    await pool.end();
    return;
  }

  logger.info(`Found ${rows.length} user(s) without a code. Assigning now...`);

  for (const user of rows) {
    const code = await generateUniqueUserCode();
    await query('UPDATE users SET user_code = $1 WHERE id = $2', [code, user.id]);
    logger.info(`Assigned ${code} to ${user.full_name} (${user.phone})`);
  }

  logger.info('Backfill complete.');
  await pool.end();
}

backfillUserCodes().catch((err) => {
  logger.error('Backfill failed', { error: err.message });
  process.exit(1);
});