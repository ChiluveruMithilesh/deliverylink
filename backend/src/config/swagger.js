'use strict';

const swaggerJsdoc = require('swagger-jsdoc');
const env = require('./env');

const options = {
  definition: {
    openapi: '3.0.3',
    info: {
      title: 'DeliveryLink API',
      version: '1.0.0',
      description:
        'REST API for DeliveryLink - a marketplace connecting FMCG distributors, auto drivers and shopkeepers for multi-stop goods delivery.',
    },
    servers: [{ url: `${env.apiBaseUrl}/api/v1`, description: 'Current environment' }],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
    },
    security: [{ bearerAuth: [] }],
  },
  // JSDoc @openapi annotations inside route files are collected from here.
  apis: ['./src/modules/**/*.routes.js'],
};

module.exports = swaggerJsdoc(options);
