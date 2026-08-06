'use strict';

const admin = require('firebase-admin');
const env = require('../config/env');
const logger = require('../utils/logger');

let initialized = false;

function initFirebase() {
  if (initialized) return admin;
  if (!env.firebase.projectId || !env.firebase.privateKey) {
    logger.warn('Firebase credentials not configured; push notifications disabled');
    return null;
  }

  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: env.firebase.projectId,
      clientEmail: env.firebase.clientEmail,
      privateKey: env.firebase.privateKey,
    }),
    storageBucket: env.firebase.storageBucket,
  });

  initialized = true;
  logger.info('Firebase Admin initialized');
  return admin;
}

module.exports = { initFirebase, admin };
