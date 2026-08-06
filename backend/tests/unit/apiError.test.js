'use strict';

const ApiError = require('../../src/utils/ApiError');

describe('ApiError', () => {
  test('badRequest sets statusCode 400 and is operational', () => {
    const err = ApiError.badRequest('Invalid input', [{ field: 'phone', message: 'required' }]);
    expect(err.statusCode).toBe(400);
    expect(err.isOperational).toBe(true);
    expect(err.details).toHaveLength(1);
  });

  test('unauthorized defaults to a sensible message', () => {
    const err = ApiError.unauthorized();
    expect(err.statusCode).toBe(401);
    expect(err.message).toBe('Unauthorized');
  });

  test('notFound sets statusCode 404', () => {
    const err = ApiError.notFound('Trip not found');
    expect(err.statusCode).toBe(404);
    expect(err.message).toBe('Trip not found');
  });

  test('internal is marked non-operational', () => {
    const err = ApiError.internal();
    expect(err.statusCode).toBe(500);
    expect(err.isOperational).toBe(false);
  });
});
