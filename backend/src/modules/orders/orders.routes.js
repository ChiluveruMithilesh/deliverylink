'use strict';

const express = require('express');
const router = express.Router();

const { authenticate, authorize } = require('../../middleware/auth');
const validate = require('../../middleware/validate');
const { createOrderRequestValidator, updateStatusValidator } = require('./orders.validators');
const ctrl = require('./orders.controller');

router.use(authenticate);

router.post('/', authorize('shopkeeper'), createOrderRequestValidator, validate, ctrl.createHandler);
router.get('/sent', authorize('shopkeeper'), ctrl.listSentHandler);
router.get('/received', authorize('distributor'), ctrl.listReceivedHandler);
router.patch('/:id/status', authorize('distributor'), updateStatusValidator, validate, ctrl.updateStatusHandler);

module.exports = router;