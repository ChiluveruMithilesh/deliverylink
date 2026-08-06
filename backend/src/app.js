'use strict';

require('express-async-errors');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const swaggerUi = require('swagger-ui-express');

const swaggerSpec = require('./config/swagger');
const requestLogger = require('./middleware/requestLogger');
const { generalLimiter } = require('./middleware/rateLimiter');
const { notFoundHandler, errorConverter, errorHandler } = require('./middleware/errorHandler');
const { checkConnection } = require('./config/database');

const app = express();

// --- Security & parsing ---
app.use(helmet());
app.use(cors({ origin: '*', credentials: true })); // tighten origin allow-list in production
app.use(compression());
app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ extended: true, limit: '2mb' }));
app.use(requestLogger);
app.use(generalLimiter);

// --- API docs ---
app.use('/api/docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// --- Health & readiness (used by Docker/orchestrator health checks) ---
app.get('/health', (req, res) => {
  res.json({ success: true, status: 'ok', uptimeSeconds: process.uptime() });
});

app.get('/ready', async (req, res, next) => {
  try {
    await checkConnection();
    res.json({ success: true, status: 'ready' });
  } catch (err) {
    next(err);
  }
});

// --- Static file serving for local uploads (dev/small-scale; use Firebase/S3+CDN at scale) ---
const { router: uploadsRouter, uploadDir } = require('./modules/uploads/uploads.routes');
app.use('/uploads', express.static(uploadDir));

// --- Feature routes ---
app.use('/api/v1/auth', require('./modules/auth/auth.routes'));
app.use('/api/v1/trips', require('./modules/trips/trips.routes'));
app.use('/api/v1/distributor', require('./modules/distributor/distributor.routes'));
app.use('/api/v1/driver', require('./modules/driver/driver.routes'));
app.use('/api/v1/shopkeeper', require('./modules/shopkeeper/shopkeeper.routes'));
app.use('/api/v1/admin', require('./modules/admin/admin.routes'));
app.use('/api/v1/notifications', require('./modules/notifications/notifications.routes'));
app.use('/api/v1/uploads', uploadsRouter);

// --- 404 + error handling (must be last) ---
app.use(notFoundHandler);
app.use(errorConverter);
app.use(errorHandler);

module.exports = app;
