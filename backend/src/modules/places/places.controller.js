'use strict';

const placesService = require('./places.service');

async function autocompleteHandler(req, res) {
  const { query, lat, lng } = req.query;
  const results = await placesService.autocompleteSearch(
    query,
    lat ? parseFloat(lat) : null,
    lng ? parseFloat(lng) : null
  );
  res.json({ success: true, data: results });
}

async function detailsHandler(req, res) {
  const { placeId } = req.query;
  const details = await placesService.getPlaceDetails(placeId);
  res.json({ success: true, data: details });
}

module.exports = { autocompleteHandler, detailsHandler };