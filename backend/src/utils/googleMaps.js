'use strict';

const https = require('https');
const env = require('../config/env');
const logger = require('./logger');

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

const EARTH_RADIUS_KM = 6371;

/**
 * Haversine straight-line distance in km. Used as a fast pre-filter
 * before calling the paid Google Distance Matrix API, and as a
 * fallback if the API is unavailable.
 */
function haversineDistanceKm(lat1, lng1, lat2, lng2) {
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dLng / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return EARTH_RADIUS_KM * c;
}

/**
 * Greedy nearest-neighbor route optimization across up to 40 stops.
 * Good enough for last-mile delivery ordering without needing an
 * expensive TSP solver; falls back to this if Directions API waypoint
 * optimization is unavailable.
 */
function optimizeStopOrder(originLat, originLng, stops) {
  const remaining = stops.map((s, idx) => ({ ...s, originalIndex: idx }));
  const ordered = [];
  let currentLat = originLat;
  let currentLng = originLng;

  while (remaining.length > 0) {
    let nearestIdx = 0;
    let nearestDist = Infinity;
    for (let i = 0; i < remaining.length; i++) {
      const d = haversineDistanceKm(currentLat, currentLng, remaining[i].lat, remaining[i].lng);
      if (d < nearestDist) {
        nearestDist = d;
        nearestIdx = i;
      }
    }
    const next = remaining.splice(nearestIdx, 1)[0];
    ordered.push(next);
    currentLat = next.lat;
    currentLng = next.lng;
  }

  return ordered;
}

/**
 * Calls Google Directions API with waypoint optimization for an
 * accurate road-network route, distance and ETA. Falls back to the
 * haversine nearest-neighbor estimate if the API call fails.
 */
async function getOptimizedRoute(originLat, originLng, stops) {
  if (!env.googleMaps.directionsApiKey) {
    logger.warn('GOOGLE_DIRECTIONS_API_KEY not configured, using haversine fallback');
    return fallbackRoute(originLat, originLng, stops);
  }

  try {
    const waypoints = stops.map((s) => `${s.lat},${s.lng}`).join('|');
    const destination = `${stops[stops.length - 1].lat},${stops[stops.length - 1].lng}`;
    const url =
      `https://maps.googleapis.com/maps/api/directions/json` +
      `?origin=${originLat},${originLng}` +
      `&destination=${destination}` +
      `&waypoints=optimize:true|${waypoints}` +
      `&key=${env.googleMaps.directionsApiKey}`;

    const data = await httpGetJson(url);

    if (data.status !== 'OK') {
      logger.warn('Directions API returned non-OK status', { status: data.status });
      return fallbackRoute(originLat, originLng, stops);
    }

    const order = data.routes[0].waypoint_order;
    const orderedStops = order.map((i) => stops[i]);
    const totalDistanceMeters = data.routes[0].legs.reduce((sum, leg) => sum + leg.distance.value, 0);
    const totalDurationSeconds = data.routes[0].legs.reduce((sum, leg) => sum + leg.duration.value, 0);

    return {
      orderedStops,
      totalDistanceKm: Math.round((totalDistanceMeters / 1000) * 10) / 10,
      totalDurationMin: Math.round(totalDurationSeconds / 60),
      polyline: data.routes[0].overview_polyline?.points || null,
      source: 'google_directions',
    };
  } catch (err) {
    logger.error('Directions API call failed, using haversine fallback', { error: err.message });
    return fallbackRoute(originLat, originLng, stops);
  }
}

function fallbackRoute(originLat, originLng, stops) {
  const orderedStops = optimizeStopOrder(originLat, originLng, stops);
  let totalDistanceKm = 0;
  let prevLat = originLat;
  let prevLng = originLng;
  for (const stop of orderedStops) {
    totalDistanceKm += haversineDistanceKm(prevLat, prevLng, stop.lat, stop.lng);
    prevLat = stop.lat;
    prevLng = stop.lng;
  }
  // Rough estimate: 25 km/h average urban/semi-urban delivery speed.
  const totalDurationMin = Math.round((totalDistanceKm / 25) * 60);

  return {
    orderedStops,
    totalDistanceKm: Math.round(totalDistanceKm * 10) / 10,
    totalDurationMin,
    polyline: null,
    source: 'haversine_fallback',
  };
}

module.exports = { haversineDistanceKm, optimizeStopOrder, getOptimizedRoute };
