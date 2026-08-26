'use strict';

/**
 * One-time utility: promotes an existing user account to the 'admin'
 * role. Admin accounts are never self-registered through the app (the
 * registration form deliberately only allows distributor/driver/
 * shopkeeper) - this script is the intended way to create the first
 * admin, run directly against the database by someone with server access.
 *
 * Usage: node src/db/promoteToAdmin.js <phone-number>
 * Example: node src/db/promoteToAdmin.js 9392202037
 */

const { pool, query } = require('../config/database');
const logger = require('../utils/logger');

async function promoteToAdmin(phone) {
  if (!phone) {
    logger.error('Usage: node src/db/promoteToAdmin.js <phone-number>');
    process.exit(1);
  }

  const { rows } = await query('SELECT id, full_name, role FROM users WHERE phone = $1', [phone]);
  const user = rows[0];

  if (!user) {
    logger.error(`No account found with phone number ${phone}`);
    await pool.end();
    process.exit(1);
  }

  if (user.role === 'admin') {
    logger.info(`${user.full_name} (${phone}) is already an admin. Nothing to do.`);
    await pool.end();
    return;
  }

  await query('UPDATE users SET role = $1 WHERE id = $2', ['admin', user.id]);
  logger.info(`Promoted ${user.full_name} (${phone}) from '${user.role}' to 'admin'.`);
  logger.info('They can now log in normally and will land on the Admin Dashboard.');

  await pool.end();
}

const phoneArg = process.argv[2];
promoteToAdmin(phoneArg).catch((err) => {
  logger.error('Promotion failed', { error: err.message });
  process.exit(1);
});