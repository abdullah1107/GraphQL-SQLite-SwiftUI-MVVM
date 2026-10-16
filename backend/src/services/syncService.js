import { db } from '../db.js';
import { dummyJson } from './dummyJsonClient.js';
import { productRepository } from '../repositories/productRepository.js';
import { cartRepository } from '../repositories/cartRepository.js';

const logSync = db.prepare(`
  INSERT INTO sync_log (entity, item_count, synced_at) VALUES (?, ?, ?)
  ON CONFLICT(entity) DO UPDATE SET item_count = excluded.item_count, synced_at = excluded.synced_at
`);

const inFlight = new Map();

/** Run one sync at a time per entity; concurrent callers share the same promise. */
function once(entity, job) {
  if (!inFlight.has(entity)) {
    inFlight.set(entity, job().finally(() => inFlight.delete(entity)));
  }
  return inFlight.get(entity);
}

export const syncService = {
  /** Pull every product from DummyJSON and upsert into SQLite. */
  syncProducts: () =>
    once('products', async () => {
      const { products } = await dummyJson.allProducts();
      const count = productRepository.saveAll(products);
      cartRepository.repriceAllLocalCarts(); // users' carts pick up new prices/titles
      const syncedAt = new Date().toISOString();
      logSync.run('products', count, syncedAt);
      return { entity: 'products', count, syncedAt };
    }),

  /** Pull every cart from DummyJSON and upsert into SQLite. */
  syncCarts: () =>
    once('carts', async () => {
      const { carts } = await dummyJson.allCarts();
      const count = cartRepository.saveAll(carts);
      const syncedAt = new Date().toISOString();
      logSync.run('carts', count, syncedAt);
      return { entity: 'carts', count, syncedAt };
    }),

  async syncAll() {
    return Promise.all([this.syncProducts(), this.syncCarts()]);
  },

  /** Seed lazily: if a table is empty the first query fills it. */
  async ensureProducts() {
    if (productRepository.count() === 0) await this.syncProducts();
  },
  async ensureCarts() {
    // Local carts alone don't count as "seeded".
    const remote = db.prepare('SELECT COUNT(*) AS n FROM carts WHERE is_local = 0').get().n;
    if (remote === 0) await this.syncCarts();
  },

  status: () =>
    db.prepare('SELECT entity, item_count, synced_at FROM sync_log ORDER BY entity').all().map((r) => ({
      entity: r.entity,
      count: r.item_count,
      syncedAt: r.synced_at,
    })),
};
