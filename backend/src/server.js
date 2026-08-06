'use strict';

const app = require('./app');
const env = require('./config/env');
const logger = require('./utils/logger');
const { checkConnection } = require('./config/database');
const { connectRedis } = require('./config/redis');

let server;

async function start() {
  try {
    const dbTime = await checkConnection();
    logger.info('PostgreSQL connection established', { serverTime: dbTime });

    await connectRedis();

    server = app.listen(env.port, () => {
      logger.info(`DeliveryLink backend listening on port ${env.port}`, {
        env: env.nodeEnv,
        docs: `${env.apiBaseUrl}/api/docs`,
      });
    });
  } catch (err) {
    logger.error('Failed to start server', { error: err.message, stack: err.stack });
    process.exit(1);
  }
}

function shutdown(signal) {
  logger.info(`${signal} received, shutting down gracefully`);
  if (server) {
    server.close(() => {
      logger.info('HTTP server closed');
      process.exit(0);
    });
    // Force exit if connections don't close in time.
    setTimeout(() => process.exit(1), 10000).unref();
  } else {
    process.exit(0);
  }
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
process.on('unhandledRejection', (reason) => {
  logger.error('Unhandled promise rejection', { reason: reason?.message || reason });
});

start();
