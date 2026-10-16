import { GraphQLError } from 'graphql';
import { config } from '../config.js';

/**
 * Thin REST client for https://dummyjson.com.
 * Every call that fails is turned into a GraphQLError so the iOS app gets a readable message.
 */
async function request(pathname, { method = 'GET', body, token } = {}) {
  const url = `${config.dummyJsonBaseUrl}${pathname}`;
  let response;
  try {
    response = await fetch(url, {
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
      signal: AbortSignal.timeout(15_000),
    });
  } catch (error) {
    throw new GraphQLError(`Could not reach DummyJSON (${url}): ${error.message}`, {
      extensions: { code: 'UPSTREAM_UNAVAILABLE' },
    });
  }

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const code = response.status === 400 || response.status === 401 ? 'UNAUTHENTICATED' : 'UPSTREAM_ERROR';
    throw new GraphQLError(payload.message ?? `DummyJSON responded with HTTP ${response.status}`, {
      extensions: { code, upstreamStatus: response.status },
    });
  }
  return payload;
}

export const dummyJson = {
  /** POST /auth/login → user fields + accessToken + refreshToken */
  login: (username, password, expiresInMins = 60) =>
    request('/auth/login', { method: 'POST', body: { username, password, expiresInMins } }),

  /** GET /auth/me → the user that owns the token */
  me: (token) => request('/auth/me', { token }),

  /** GET /products?limit=0 → every product (limit=0 disables paging on DummyJSON) */
  allProducts: () => request('/products?limit=0'),

  /** GET /carts?limit=0 → every cart */
  allCarts: () => request('/carts?limit=0'),
};
