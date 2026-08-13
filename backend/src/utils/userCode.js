'use strict';

const { query } = require('../config/database');

// Excludes visually ambiguous characters (0/O, 1/I/L) so codes are easy
// to read aloud and type correctly on a low-end phone keyboard.
const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const CODE_LENGTH = 6;
const MAX_ATTEMPTS = 10;

function randomCode() {
  let code = '';
  for (let i = 0; i < CODE_LENGTH; i++) {
    code += CODE_ALPHABET[Math.floor(Math.random() * CODE_ALPHABET.length)];
  }
  return `DL-${code}`;
}

/**
 * Generates a unique, human-shareable user code (e.g. "DL-7K2M9X").
 * Retries on the rare collision rather than trusting randomness alone,
 * since the column has a UNIQUE constraint as the real guarantee.
 */
async function generateUniqueUserCode() {
  for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
    const candidate = randomCode();
    const { rows } = await query('SELECT 1 FROM users WHERE user_code = $1', [candidate]);
    if (rows.length === 0) return candidate;
  }
  throw new Error('Failed to generate a unique user code after multiple attempts');
}

module.exports = { generateUniqueUserCode };