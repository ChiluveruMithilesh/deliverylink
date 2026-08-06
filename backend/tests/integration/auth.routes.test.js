'use strict';

const request = require('supertest');
const app = require('../../src/app');

describe('POST /api/v1/auth/register - validation', () => {
  test('rejects an invalid role', async () => {
    const res = await request(app).post('/api/v1/auth/register').send({
      role: 'superadmin',
      fullName: 'Test User',
      phone: '9876543210',
      password: 'password123',
    });
    expect(res.status).toBe(400);
    expect(res.body.error.details.some((d) => d.field === 'role')).toBe(true);
  });

  test('rejects a malformed phone number', async () => {
    const res = await request(app).post('/api/v1/auth/register').send({
      role: 'distributor',
      fullName: 'Test User',
      phone: '12345',
      password: 'password123',
      businessName: 'ABC Traders',
    });
    expect(res.status).toBe(400);
    expect(res.body.error.details.some((d) => d.field === 'phone')).toBe(true);
  });

  test('rejects a distributor without businessName', async () => {
    const res = await request(app).post('/api/v1/auth/register').send({
      role: 'distributor',
      fullName: 'Test User',
      phone: '9876543210',
      password: 'password123',
    });
    expect(res.status).toBe(400);
    expect(res.body.error.details.some((d) => d.field === 'businessName')).toBe(true);
  });

  test('rejects a short password', async () => {
    const res = await request(app).post('/api/v1/auth/register').send({
      role: 'distributor',
      fullName: 'Test User',
      phone: '9876543210',
      password: 'short',
      businessName: 'ABC Traders',
    });
    expect(res.status).toBe(400);
    expect(res.body.error.details.some((d) => d.field === 'password')).toBe(true);
  });
});

describe('GET /api/v1/auth/me - authentication required', () => {
  test('rejects a request with no Authorization header', async () => {
    const res = await request(app).get('/api/v1/auth/me');
    expect(res.status).toBe(401);
  });

  test('rejects a malformed bearer token', async () => {
    const res = await request(app).get('/api/v1/auth/me').set('Authorization', 'Bearer not-a-real-token');
    expect(res.status).toBe(401);
  });
});
