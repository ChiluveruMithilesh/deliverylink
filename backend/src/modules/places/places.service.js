'use strict';

const https = require('https');
const env = require('../../config/env');
const ApiError = require('../../utils/ApiError');
const logger = require('../../utils/logger');

function httpGetJson(url) {
  return new Promise((resolve, reject) => {
    https
      .get(url, (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          try {
            resolve(JSON.parse(data));
          } catch (err) {
            reject(err);
          }
        });
      })
      .on('error', reject);
  });
}

async function autocompleteSearch(query, lat, lng) {
  if (!env.googleMaps.mapsApiKey) {
    throw ApiError.internal('Location search is not configured on the server yet.');
  }

  let url =
    `https://maps.googleapis.com/maps/api/place/autocomplete/json` +
    `?input=${encodeURIComponent(query)}` +
    `&key=${env.googleMaps.mapsApiKey}`;

  if (lat != null && lng != null) {
    url += `&location=${lat},${lng}&radius=30000`;
  }

  const data = await httpGetJson(url);

  if (data.status !== 'OK' && data.status !== 'ZERO_RESULTS') {
    logger.warn('Places Autocomplete non-OK status', { status: data.status, error: data.error_message });
    throw ApiError.internal('Location search is temporarily unavailable.');
  }

  return (data.predictions || []).map((p) => ({
    placeId: p.place_id,
    description: p.description,
  }));
}

async function getPlaceDetails(placeId) {
  if (!env.googleMaps.mapsApiKey) {
    throw ApiError.internal('Location search is not configured on the server yet.');
  }

  const url =
    `https://maps.googleapis.com/maps/api/place/details/json` +
    `?place_id=${encodeURIComponent(placeId)}` +
    `&fields=geometry,formatted_address,name` +
    `&key=${env.googleMaps.mapsApiKey}`;

  const data = await httpGetJson(url);

  if (data.status !== 'OK') {
    logger.warn('Place Details non-OK status', { status: data.status, error: data.error_message });
    throw ApiError.notFound('Could not find details for that location.');
  }

  const result = data.result;
  return {
    name: result.name,
    formattedAddress: result.formatted_address,
    lat: result.geometry.location.lat,
    lng: result.geometry.location.lng,
  };
}

module.exports = { autocompleteSearch, getPlaceDetails };