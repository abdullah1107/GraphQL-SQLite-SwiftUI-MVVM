import { db, transaction } from '../db.js';

/** Carts created through this API get ids from here up, so a DummyJSON re-sync never overwrites them. */
const LOCAL_CART_ID_START = 100_000;

const round2 = (n) => Math.round(n * 100) / 100;

const toCart = (row) =>
  row && {
    id: row.id,
    userId: row.user_id,
    total: row.total,
    discountedTotal: row.discounted_total,
    totalProducts: row.total_products,
    totalQuantity: row.total_quantity,
    isLocal: row.is_local === 1,
    syncedAt: row.synced_at,
  };

const toCartItem = (row) => ({
  productId: row.product_id,
  title: row.title,
  price: row.price,
  quantity: row.quantity,
  total: row.total,
  discountPercentage: row.discount_percentage,
  discountedTotal: row.discounted_total,
  thumbnail: row.thumbnail,
});

const upsertRemoteCart = db.prepare(`
  INSERT INTO carts (id, user_id, total, discounted_total, total_products, total_quantity, is_local, synced_at)
  VALUES (@id, @userId, @total, @discountedTotal, @totalProducts, @totalQuantity, 0, @syncedAt)
  ON CONFLICT(id) DO UPDATE SET
    user_id = excluded.user_id, total = excluded.total, discounted_total = excluded.discounted_total,
    total_products = excluded.total_products, total_quantity = excluded.total_quantity,
    synced_at = excluded.synced_at
  WHERE carts.is_local = 0
`);
const deleteItems = db.prepare('DELETE FROM cart_items WHERE cart_id = ?');
const insertItem = db.prepare(`
  INSERT INTO cart_items (cart_id, product_id, title, price, quantity, total, discount_percentage, discounted_total, thumbnail)
  VALUES (@cartId, @productId, @title, @price, @quantity, @total, @discountPercentage, @discountedTotal, @thumbnail)
  ON CONFLICT(cart_id, product_id) DO UPDATE SET
    title = excluded.title, price = excluded.price, quantity = excluded.quantity, total = excluded.total,
    discount_percentage = excluded.discount_percentage, discounted_total = excluded.discounted_total,
    thumbnail = excluded.thumbnail
`);

/**
 * Copy the latest title / price / discount / thumbnail from the products table into a local cart's lines
 * and recompute each line total. Keeps "your cart" in step with the product catalogue.
 */
const repriceItems = db.prepare(`
  UPDATE cart_items SET
    title               = p.title,
    price               = p.price,
    discount_percentage = COALESCE(p.discount_percentage, 0),
    thumbnail           = p.thumbnail,
    total               = ROUND(p.price * cart_items.quantity, 2),
    discounted_total    = ROUND(p.price * cart_items.quantity * (1 - COALESCE(p.discount_percentage, 0) / 100.0), 2)
  FROM products p
  WHERE p.id = cart_items.product_id AND cart_items.cart_id = ?
`);

/** Recompute the cart header (totals, counts) from its lines. */
function recalculateTotals(cartId) {
  const t = db.prepare(`
    SELECT COALESCE(SUM(total), 0) AS total, COALESCE(SUM(discounted_total), 0) AS discounted,
           COUNT(*) AS products, COALESCE(SUM(quantity), 0) AS quantity
    FROM cart_items WHERE cart_id = ?
  `).get(cartId);
  db.prepare(`
    UPDATE carts SET total = ?, discounted_total = ?, total_products = ?, total_quantity = ?, synced_at = ?
    WHERE id = ?
  `).run(round2(t.total), round2(t.discounted), t.products, t.quantity, new Date().toISOString(), cartId);
}

/** Reprice + recompute, then return the fresh cart. */
function refreshLocalCart(cartId) {
  repriceItems.run(cartId);
  recalculateTotals(cartId);
  return toCart(db.prepare('SELECT * FROM carts WHERE id = ?').get(cartId));
}

const findLocalCartRow = (userId) =>
  db.prepare('SELECT * FROM carts WHERE user_id = ? AND is_local = 1 ORDER BY id LIMIT 1').get(userId);

function localCartFor(userId) {
  const existing = findLocalCartRow(userId);
  if (existing) return existing;
  const { maxId } = db.prepare('SELECT MAX(id) AS maxId FROM carts').get();
  const id = Math.max(maxId ?? 0, LOCAL_CART_ID_START - 1) + 1;
  db.prepare(`
    INSERT INTO carts (id, user_id, total, discounted_total, total_products, total_quantity, is_local, synced_at)
    VALUES (?, ?, 0, 0, 0, 0, 1, ?)
  `).run(id, userId, new Date().toISOString());
  return db.prepare('SELECT * FROM carts WHERE id = ?').get(id);
}

function writeItem(cartId, product, quantity) {
  const total = round2(product.price * quantity);
  const discount = product.discountPercentage ?? 0;
  insertItem.run({
    cartId,
    productId: product.id,
    title: product.title,
    price: product.price,
    quantity,
    total,
    discountPercentage: discount,
    discountedTotal: round2(total * (1 - discount / 100)),
    thumbnail: product.thumbnail ?? null,
  });
}

export const cartRepository = {
  /** Insert or update the carts that came from DummyJSON, replacing their line items. */
  saveAll(carts) {
    const syncedAt = new Date().toISOString();
    transaction(() => {
      for (const c of carts) {
        const result = upsertRemoteCart.run({
          id: c.id,
          userId: c.userId,
          total: c.total,
          discountedTotal: c.discountedTotal,
          totalProducts: c.totalProducts,
          totalQuantity: c.totalQuantity,
          syncedAt,
        });
        if (result.changes === 0) continue; // id belongs to a local cart; leave it alone
        deleteItems.run(c.id);
        for (const item of c.products ?? []) {
          insertItem.run({
            cartId: c.id,
            productId: item.id,
            title: item.title,
            price: item.price,
            quantity: item.quantity,
            total: item.total,
            discountPercentage: item.discountPercentage ?? 0,
            discountedTotal: item.discountedTotal ?? item.total,
            thumbnail: item.thumbnail ?? null,
          });
        }
      }
    });
    return carts.length;
  },

  count: () => db.prepare('SELECT COUNT(*) AS n FROM carts').get().n,

  findById: (id) => toCart(db.prepare('SELECT * FROM carts WHERE id = ?').get(id)),

  findPage({ userId, limit = 20, skip = 0 }) {
    const whereSql = userId != null ? 'WHERE user_id = @userId' : '';
    const params = userId != null ? { userId } : {};
    const safeLimit = Math.min(Math.max(limit, 1), 100);
    const safeSkip = Math.max(skip, 0);
    const total = db.prepare(`SELECT COUNT(*) AS n FROM carts ${whereSql}`).get(params).n;
    const rows = db
      .prepare(`SELECT * FROM carts ${whereSql} ORDER BY id LIMIT @limit OFFSET @skip`)
      .all({ ...params, limit: safeLimit, skip: safeSkip });
    return {
      items: rows.map(toCart),
      total,
      skip: safeSkip,
      limit: safeLimit,
      hasMore: safeSkip + rows.length < total,
    };
  },

  findByUser: (userId) =>
    db.prepare('SELECT * FROM carts WHERE user_id = ? ORDER BY is_local DESC, id').all(userId).map(toCart),

  itemsFor: (cartId) =>
    db.prepare('SELECT * FROM cart_items WHERE cart_id = ? ORDER BY rowid').all(cartId).map(toCartItem),

  // ---------------------------------------------------------------------------
  // The logged-in user's own ("local") cart
  // ---------------------------------------------------------------------------

  /** The user's cart with prices refreshed from the products table, or null if they never added anything. */
  findLocalCart(userId) {
    const row = findLocalCartRow(userId);
    return row ? transaction(() => refreshLocalCart(row.id)) : null;
  },

  /** Quantity of a product already in the user's cart (0 if none). */
  quantityInLocalCart(userId, productId) {
    const row = db.prepare(`
      SELECT ci.quantity FROM cart_items ci JOIN carts c ON c.id = ci.cart_id
      WHERE c.user_id = ? AND c.is_local = 1 AND ci.product_id = ?
    `).get(userId, productId);
    return row?.quantity ?? 0;
  },

  /** Add `quantity` of a product (creating the cart if needed). Existing lines are increased. */
  addItem(userId, product, quantity) {
    return transaction(() => {
      const cart = localCartFor(userId);
      writeItem(cart.id, product, this.quantityInLocalCart(userId, product.id) + quantity);
      return refreshLocalCart(cart.id);
    });
  },

  /** Set the quantity of a product. 0 removes the line. */
  setItemQuantity(userId, product, quantity) {
    return transaction(() => {
      const cart = localCartFor(userId);
      if (quantity <= 0) {
        db.prepare('DELETE FROM cart_items WHERE cart_id = ? AND product_id = ?').run(cart.id, product.id);
      } else {
        writeItem(cart.id, product, quantity);
      }
      return refreshLocalCart(cart.id);
    });
  },

  /** Delete one product line. Returns null if the user has no cart. */
  removeItem(userId, productId) {
    return transaction(() => {
      const row = findLocalCartRow(userId);
      if (!row) return null;
      db.prepare('DELETE FROM cart_items WHERE cart_id = ? AND product_id = ?').run(row.id, productId);
      return refreshLocalCart(row.id);
    });
  },

  /** Delete every line in the user's cart (the cart itself stays, empty). */
  clear(userId) {
    return transaction(() => {
      const cart = localCartFor(userId);
      deleteItems.run(cart.id);
      return refreshLocalCart(cart.id);
    });
  },

  /** After a product sync, bring every local cart's prices up to date. */
  repriceAllLocalCarts() {
    transaction(() => {
      for (const { id } of db.prepare('SELECT id FROM carts WHERE is_local = 1').all()) refreshLocalCart(id);
    });
  },
};
