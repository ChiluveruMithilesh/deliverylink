'use strict';

const { haversineDistanceKm, optimizeStopOrder } = require('../../src/utils/googleMaps');

describe('haversineDistanceKm', () => {
  test('distance between identical points is 0', () => {
    expect(haversineDistanceKm(17.385, 78.4867, 17.385, 78.4867)).toBe(0);
  });

  test('distance between Hyderabad and Vijayawada is roughly 275km', () => {
    // Hyderabad: 17.385, 78.4867 | Vijayawada: 16.5062, 80.6480
    const distance = haversineDistanceKm(17.385, 78.4867, 16.5062, 80.648);
    expect(distance).toBeGreaterThan(230);
    expect(distance).toBeLessThan(280);
  });
});

describe('optimizeStopOrder', () => {
  test('returns all stops with no duplicates or omissions', () => {
    const stops = [
      { shopName: 'A', lat: 17.4, lng: 78.5 },
      { shopName: 'B', lat: 17.5, lng: 78.6 },
      { shopName: 'C', lat: 17.3, lng: 78.4 },
    ];
    const ordered = optimizeStopOrder(17.385, 78.4867, stops);
    expect(ordered).toHaveLength(3);
    expect(new Set(ordered.map((s) => s.shopName))).toEqual(new Set(['A', 'B', 'C']));
  });

  test('nearest-neighbor picks the closest stop to origin first', () => {
    const stops = [
      { shopName: 'Far', lat: 20.0, lng: 80.0 },
      { shopName: 'Near', lat: 17.386, lng: 78.4868 },
    ];
    const ordered = optimizeStopOrder(17.385, 78.4867, stops);
    expect(ordered[0].shopName).toBe('Near');
  });
});
