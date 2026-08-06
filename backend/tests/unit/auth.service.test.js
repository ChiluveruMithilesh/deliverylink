'use strict';

jest.mock('../../src/config/database', () => ({
  query: jest.fn(),
  withTransaction: jest.fn(),
}));

const bcrypt = require('bcryptjs');
const { query, withTransaction } = require('../../src/config/database');
const authService = require('../../src/modules/auth/auth.service');

describe('authService.register', () => {
  afterEach(() => jest.clearAllMocks());

  test('throws a conflict error if phone already registered', async () => {
    query.mockResolvedValueOnce({ rows: [{ id: 'existing-user-id' }] });

    await expect(
      authService.register({
        role: 'distributor',
        fullName: 'Test User',
        phone: '9876543210',
        password: 'password123',
        businessName: 'ABC Traders',
      })
    ).rejects.toMatchObject({ statusCode: 409 });
  });

  test('creates a distributor profile inside the same transaction', async () => {
    query.mockResolvedValueOnce({ rows: [] }); // phone not taken

    const mockClient = {
      query: jest
        .fn()
        .mockResolvedValueOnce({
          rows: [{ id: 'user-1', role: 'distributor', full_name: 'Test User', phone: '9876543210' }],
        })
        .mockResolvedValueOnce({ rows: [] }), // distributor insert
    };
    withTransaction.mockImplementation((callback) => callback(mockClient));

    const result = await authService.register({
      role: 'distributor',
      fullName: 'Test User',
      phone: '9876543210',
      password: 'password123',
      businessName: 'ABC Traders',
    });

    expect(result.user.id).toBe('user-1');
    expect(result.accessToken).toBeDefined();
    expect(result.refreshToken).toBeDefined();
    expect(mockClient.query).toHaveBeenCalledTimes(2);
  });
});

describe('authService.login', () => {
  afterEach(() => jest.clearAllMocks());

  test('rejects with 401 when phone does not exist', async () => {
    query.mockResolvedValueOnce({ rows: [] });

    await expect(authService.login('9876543210', 'anypassword')).rejects.toMatchObject({
      statusCode: 401,
    });
  });

  test('rejects with 401 when password is incorrect', async () => {
    const passwordHash = await bcrypt.hash('correctpassword', 12);
    query.mockResolvedValueOnce({
      rows: [
        {
          id: 'user-1',
          role: 'distributor',
          full_name: 'Test User',
          phone: '9876543210',
          password_hash: passwordHash,
          is_active: true,
        },
      ],
    });

    await expect(authService.login('9876543210', 'wrongpassword')).rejects.toMatchObject({
      statusCode: 401,
    });
  });

  test('succeeds and returns tokens for correct credentials', async () => {
    const passwordHash = await bcrypt.hash('correctpassword', 12);
    query
      .mockResolvedValueOnce({
        rows: [
          {
            id: 'user-1',
            role: 'distributor',
            full_name: 'Test User',
            phone: '9876543210',
            password_hash: passwordHash,
            is_active: true,
          },
        ],
      })
      .mockResolvedValueOnce({ rows: [] }); // last_login_at update

    const result = await authService.login('9876543210', 'correctpassword');
    expect(result.user.id).toBe('user-1');
    expect(result.accessToken).toBeDefined();
  });

  test('rejects with 403 when account is deactivated', async () => {
    const passwordHash = await bcrypt.hash('correctpassword', 12);
    query.mockResolvedValueOnce({
      rows: [
        {
          id: 'user-1',
          role: 'distributor',
          full_name: 'Test User',
          phone: '9876543210',
          password_hash: passwordHash,
          is_active: false,
        },
      ],
    });

    await expect(authService.login('9876543210', 'correctpassword')).rejects.toMatchObject({
      statusCode: 403,
    });
  });
});
