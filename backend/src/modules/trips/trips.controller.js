'use strict';

const tripsService = require('./trips.service');

async function createHandler(req, res) {
  const trip = await tripsService.createTrip(req.user.id, req.body);
  res.status(201).json({ success: true, data: trip });
}

async function updateHandler(req, res) {
  const trip = await tripsService.updateTrip(req.user.id, req.params.id, req.body);
  res.json({ success: true, data: trip });
}

async function publishHandler(req, res) {
  const trip = await tripsService.publishTrip(req.user.id, req.params.id);
  res.json({ success: true, data: trip });
}

async function cancelHandler(req, res) {
  const trip = await tripsService.cancelTrip(req.user.id, req.params.id, req.body.reason);
  res.json({ success: true, data: trip });
}

async function getByIdHandler(req, res) {
  const trip = await tripsService.getTripById(req.params.id);
  res.json({ success: true, data: trip });
}

async function listMineHandler(req, res) {
  const { status, page, limit } = req.query;
  const trips = await tripsService.listDistributorTrips(req.user.id, {
    status,
    page: parseInt(page, 10) || 1,
    limit: Math.min(parseInt(limit, 10) || 20, 100),
  });
  res.json({ success: true, data: trips });
}

async function nearbyHandler(req, res) {
  const { lat, lng, radiusKm } = req.query;
  const trips = await tripsService.listNearbyTrips(
    req.user.id,
    parseFloat(lat),
    parseFloat(lng),
    radiusKm ? parseFloat(radiusKm) : 20
  );
  res.json({ success: true, data: trips });
}

async function placeBidHandler(req, res) {
  const bid = await tripsService.placeBid(req.user.id, req.params.id, req.body.offeredAmount);
  res.status(201).json({ success: true, data: bid });
}

async function rejectBidHandler(req, res) {
  const bid = await tripsService.rejectBid(req.user.id, req.params.id);
  res.status(201).json({ success: true, data: bid });
}

async function listBidsHandler(req, res) {
  const bids = await tripsService.listBids(req.user.id, req.params.id);
  res.json({ success: true, data: bids });
}

async function selectBidHandler(req, res) {
  const trip = await tripsService.selectBid(req.user.id, req.params.id, req.params.bidId);
  res.json({ success: true, data: trip });
}

async function confirmPickupHandler(req, res) {
  const trip = await tripsService.confirmPickup(req.user.id, req.params.id);
  res.json({ success: true, data: trip });
}

async function locationPingHandler(req, res) {
  const result = await tripsService.recordLocationPing(
    req.user.id,
    req.params.id,
    req.body.lat,
    req.body.lng
  );
  res.json({ success: true, data: result });
}

async function trackHandler(req, res) {
  const tracking = await tripsService.getLiveTracking(req.user, req.params.id);
  res.json({ success: true, data: tracking });
}

async function arriveHandler(req, res) {
  const stop = await tripsService.arriveAtStop(req.user.id, req.params.id, req.params.stopId);
  res.json({ success: true, data: stop });
}

async function deliverHandler(req, res) {
  const trip = await tripsService.deliverStop(req.user.id, req.params.id, req.params.stopId, req.body);
  res.json({ success: true, data: trip });
}

module.exports = {
  createHandler,
  updateHandler,
  publishHandler,
  cancelHandler,
  getByIdHandler,
  listMineHandler,
  nearbyHandler,
  placeBidHandler,
  rejectBidHandler,
  listBidsHandler,
  selectBidHandler,
  confirmPickupHandler,
  locationPingHandler,
  trackHandler,
  arriveHandler,
  deliverHandler,
};
