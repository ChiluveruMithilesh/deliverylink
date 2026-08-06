'use strict';

const { signAccessToken, signRefreshToken, verifyAccessToken, verifyRefreshToken } = require('../../src/utils/jwt');

describe('JWT utils', () => {
  const user = { id: 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', role: 'distributor' };

  test('access token round-trips and carries role/subject', () => {
    const token = signAccessToken(user);
    const decoded = verifyAccessToken(token);
    expect(decoded.sub).toBe(user.id);
    expect(decoded.role).toBe(user.role);
    expect(decoded.type).toBe('access');
  });

  test('refresh token round-trips with type=refresh', () => {
    const token = signRefreshToken(user);
    const decoded = verifyRefreshToken(token);
    expect(decoded.type).toBe('refresh');
  });

  test('an access token fails refresh verification with wrong secret family', () => {
    const accessToken = signAccessToken(user);
    expect(() => verifyRefreshToken(accessToken)).toThrow();
  });

  test('tampered token fails verification', () => {
    const token = signAccessToken(user);
    const tampered = token.slice(0, -2) + 'xx';
    expect(() => verifyAccessToken(tampered)).toThrow();
  });
});
