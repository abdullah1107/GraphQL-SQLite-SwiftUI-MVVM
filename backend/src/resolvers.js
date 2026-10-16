import { GraphQLError } from 'graphql';
import { dummyJson } from './services/dummyJsonClient.js';
import { syncService } from './services/syncService.js';
import { productRepository } from './repositories/productRepository.js';
import { cartRepository } from './repositories/cartRepository.js';
import { userRepository } from './repositories/userRepository.js';

async function requireUser(ctx) {
  const user = await ctx.getUser();
  if (!user) {
    throw new GraphQLError('You must be logged in. Send "Authorization: Bearer <accessToken>".', {
      extensions: { code: 'UNAUTHENTICATED' },
    });
  }
  return user;
}

async function requireProduct(productId) {
  await syncService.ensureProducts();
  const product = productRepository.findById(productId);
  if (!product) {
    throw new GraphQLError(`Product ${productId} not found`, { extensions: { code: 'NOT_FOUND' } });
  }
  return product;
}

/** Don't let the cart hold more than the product's stock. */
function requireStock(product, wantedQuantity) {
  if (product.stock != null && wantedQuantity > product.stock) {
    throw new GraphQLError(
      `Only ${product.stock} of "${product.title}" in stock (you asked for ${wantedQuantity}).`,
      { extensions: { code: 'BAD_USER_INPUT' } },
    );
  }
}

function requirePositive(value, name) {
  if (!Number.isInteger(value) || value < 1) {
    throw new GraphQLError(`${name} must be a positive integer`, { extensions: { code: 'BAD_USER_INPUT' } });
  }
}

export const resolvers = {
  Query: {
    me: (_, __, ctx) => requireUser(ctx),

    products: async (_, args) => {
      await syncService.ensureProducts();
      return productRepository.findPage(args);
    },

    product: async (_, { id }) => {
      await syncService.ensureProducts();
      return productRepository.findById(id);
    },

    categories: async () => {
      await syncService.ensureProducts();
      return productRepository.categories();
    },

    carts: async (_, args) => {
      await syncService.ensureCarts();
      return cartRepository.findPage(args);
    },

    cart: async (_, { id }) => {
      await syncService.ensureCarts();
      return cartRepository.findById(id);
    },

    myCarts: async (_, __, ctx) => {
      const user = await requireUser(ctx);
      await syncService.ensureCarts();
      return cartRepository.findByUser(user.id);
    },

    myCart: async (_, __, ctx) => {
      const user = await requireUser(ctx);
      return cartRepository.findLocalCart(user.id);
    },

    syncStatus: () => syncService.status(),
  },

  Mutation: {
    login: async (_, { username, password, expiresInMins }) => {
      const payload = await dummyJson.login(username, password, expiresInMins);
      // Older DummyJSON versions returned `token` instead of `accessToken`.
      payload.accessToken ??= payload.token;
      const user = userRepository.saveLogin(payload);
      return { accessToken: payload.accessToken, refreshToken: payload.refreshToken, user };
    },

    logout: async (_, __, ctx) => {
      await requireUser(ctx);
      return userRepository.revokeSession(ctx.token);
    },

    syncProducts: () => syncService.syncProducts(),
    syncCarts: () => syncService.syncCarts(),
    syncAll: () => syncService.syncAll(),

    addToCart: async (_, { productId, quantity }, ctx) => {
      const user = await requireUser(ctx);
      requirePositive(quantity, 'quantity');
      const product = await requireProduct(productId);
      requireStock(product, cartRepository.quantityInLocalCart(user.id, productId) + quantity);
      return cartRepository.addItem(user.id, product, quantity);
    },

    updateCartItem: async (_, { productId, quantity }, ctx) => {
      const user = await requireUser(ctx);
      if (!Number.isInteger(quantity) || quantity < 0) {
        throw new GraphQLError('quantity must be 0 or more', { extensions: { code: 'BAD_USER_INPUT' } });
      }
      const product = await requireProduct(productId);
      requireStock(product, quantity);
      return cartRepository.setItemQuantity(user.id, product, quantity);
    },

    removeFromCart: async (_, { productId }, ctx) => {
      const user = await requireUser(ctx);
      const cart = cartRepository.removeItem(user.id, productId);
      if (!cart) {
        throw new GraphQLError('You have no cart yet', { extensions: { code: 'NOT_FOUND' } });
      }
      return cart;
    },

    clearCart: async (_, __, ctx) => {
      const user = await requireUser(ctx);
      return cartRepository.clear(user.id);
    },
  },

  User: {
    fullName: (u) => [u.firstName, u.lastName].filter(Boolean).join(' ') || u.username,
    carts: (u) => cartRepository.findByUser(u.id),
  },

  Product: {
    finalPrice: (p) => Math.round(p.price * (1 - (p.discountPercentage ?? 0) / 100) * 100) / 100,
    reviews: (p) => productRepository.reviewsFor(p.id),
  },

  Cart: {
    items: (c) => cartRepository.itemsFor(c.id),
    updatedAt: (c) => c.syncedAt,
  },

  CartItem: {
    finalPrice: (item) => Math.round(item.price * (1 - (item.discountPercentage ?? 0) / 100) * 100) / 100,
    product: (item) => productRepository.findById(item.productId),
  },
};

/** Builds the per-request context: the bearer token and a lazy, cached user lookup. */
export function buildContext(req) {
  const header = req.headers.authorization ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7).trim() : null;
  let userPromise;

  return {
    token,
    getUser() {
      if (!token) return Promise.resolve(null);
      userPromise ??= (async () => {
        const session = userRepository.findSession(token);
        if (session) return session.revoked ? null : session.user;
        // Token not seen before (e.g. server DB was reset): verify it with DummyJSON /auth/me.
        try {
          const remote = await dummyJson.me(token);
          const user = userRepository.save(remote);
          userRepository.saveSession({ accessToken: token, userId: user.id });
          return user;
        } catch {
          return null;
        }
      })();
      return userPromise;
    },
  };
}
