'use strict';

const winston = require('winston');
const env = require('../config/env');

const { combine, timestamp, printf, colorize, errors, json } = winston.format;

const consoleFormat = combine(
  colorize(),
  timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  errors({ stack: true }),
  printf(({ level, message, timestamp: ts, stack, ...meta }) => {
    const metaStr = Object.keys(meta).length ? ` ${JSON.stringify(meta)}` : '';
    return `${ts} [${level}]: ${stack || message}${metaStr}`;
  })
);

const logger = winston.createLogger({
  level: env.logLevel,
  format: combine(timestamp(), errors({ stack: true }), json()),
  defaultMeta: { service: 'deliverylink-backend' },
  transports: [
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/combined.log' }),
  ],
  exitOnError: false,
});

// Always log to the console/stdout, in every environment. Render (and
// most hosting platforms) capture whatever a container prints to
// stdout as its "Logs" - they cannot see files written inside the
// container's own filesystem, which also get wiped on every restart.
// Writing only to local files in production meant every error we
// logged was going into a void nobody could ever read.
logger.add(
  new winston.transports.Console({
    format: env.nodeEnv === 'production' ? combine(timestamp(), errors({ stack: true }), json()) : consoleFormat,
  })
);

module.exports = logger;
