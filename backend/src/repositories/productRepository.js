import { db, transaction } from '../db.js';

const SORTABLE = {
  ID: 'id',
  TITLE: 'title COLLATE NOCASE',
  PRICE: 'price',
  RATING: 'rating',
  STOCK: 'stock',
};

const parseJson = (value, fallback) => {
  if (value == null) return fallback;
  try { return JSON.parse(value); } catch { return fallback; }
};

/** DB row (snake_case) → GraphQL Product (camelCase). */
export const toProduct = (row) =>
  row && {
    id: row.id,
    title: row.title,
    description: row.description,
    category: row.category,
    price: row.price,
    discountPercentage: row.discount_percentage,
    rating: row.rating,
    stock: row.stock,
    brand: row.brand,
    sku: row.sku,
    weight: row.weight,
    warrantyInformation: row.warranty_information,
    shippingInformation: row.shipping_information,
    availabilityStatus: row.availability_status,
    returnPolicy: row.return_policy,
    minimumOrderQuantity: row.minimum_order_quantity,
    thumbnail: row.thumbnail,
    tags: parseJson(row.tags, []),
    images: parseJson(row.images, []),
    dimensions: parseJson(row.dimensions, null),
    meta: parseJson(row.meta, null),
    syncedAt: row.synced_at,
  };

const upsertProduct = db.prepare(`
  INSERT INTO products (
    id, title, description, category, price, discount_percentage, rating, stock, brand, sku, weight,
    warranty_information, shipping_information, availability_status, return_policy, minimum_order_quantity,
    thumbnail, tags, images, dimensions, meta, synced_at
  ) VALUES (
    @id, @title, @description, @category, @price, @discountPercentage, @rating, @stock, @brand, @sku, @weight,
    @warrantyInformation, @shippingInformation, @availabilityStatus, @returnPolicy, @minimumOrderQuantity,
    @thumbnail, @tags, @images, @dimensions, @meta, @syncedAt
  )
  ON CONFLICT(id) DO UPDATE SET
    title = excluded.title, description = excluded.description, category = excluded.category,
    price = excluded.price, discount_percentage = excluded.discount_percentage, rating = excluded.rating,
    stock = excluded.stock, brand = excluded.brand, sku = excluded.sku, weight = excluded.weight,
    warranty_information = excluded.warranty_information, shipping_information = excluded.shipping_information,
    availability_status = excluded.availability_status, return_policy = excluded.return_policy,
    minimum_order_quantity = excluded.minimum_order_quantity, thumbnail = excluded.thumbnail,
    tags = excluded.tags, images = excluded.images, dimensions = excluded.dimensions, meta = excluded.meta,
    synced_at = excluded.synced_at
`);
const deleteReviews = db.prepare('DELETE FROM reviews WHERE product_id = ?');
const insertReview = db.prepare(`
  INSERT INTO reviews (product_id, rating, comment, date, reviewer_name, reviewer_email)
  VALUES (@productId, @rating, @comment, @date, @reviewerName, @reviewerEmail)
`);

export const productRepository = {
  /** Insert or update every product (and replace its reviews) in one transaction. */
  saveAll(products) {
    const syncedAt = new Date().toISOString();
    transaction(() => {
      for (const p of products) {
        upsertProduct.run({
          id: p.id,
          title: p.title,
          description: p.description ?? null,
          category: p.category ?? null,
          price: p.price ?? 0,
          discountPercentage: p.discountPercentage ?? null,
          rating: p.rating ?? null,
          stock: p.stock ?? null,
          brand: p.brand ?? null,
          sku: p.sku ?? null,
          weight: p.weight ?? null,
          warrantyInformation: p.warrantyInformation ?? null,
          shippingInformation: p.shippingInformation ?? null,
          availabilityStatus: p.availabilityStatus ?? null,
          returnPolicy: p.returnPolicy ?? null,
          minimumOrderQuantity: p.minimumOrderQuantity ?? null,
          thumbnail: p.thumbnail ?? null,
          tags: JSON.stringify(p.tags ?? []),
          images: JSON.stringify(p.images ?? []),
          dimensions: p.dimensions ? JSON.stringify(p.dimensions) : null,
          meta: p.meta ? JSON.stringify(p.meta) : null,
          syncedAt,
        });
        deleteReviews.run(p.id);
        for (const r of p.reviews ?? []) {
          insertReview.run({
            productId: p.id,
            rating: r.rating ?? null,
            comment: r.comment ?? null,
            date: r.date ?? null,
            reviewerName: r.reviewerName ?? null,
            reviewerEmail: r.reviewerEmail ?? null,
          });
        }
      }
    });
    return products.length;
  },

  count: () => db.prepare('SELECT COUNT(*) AS n FROM products').get().n,

  findById: (id) => toProduct(db.prepare('SELECT * FROM products WHERE id = ?').get(id)),

  /** Paged search used by the `products` query. */
  findPage({ search, category, limit = 20, skip = 0, sortBy = 'ID', order = 'ASC' }) {
    const where = [];
    const params = {};
    if (search) {
      where.push('(title LIKE @search OR description LIKE @search OR brand LIKE @search)');
      params.search = `%${search}%`;
    }
    if (category) {
      where.push('category = @category');
      params.category = category;
    }
    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
    const orderSql = `${SORTABLE[sortBy] ?? 'id'} ${order === 'DESC' ? 'DESC' : 'ASC'}`;
    const safeLimit = Math.min(Math.max(limit, 1), 100);
    const safeSkip = Math.max(skip, 0);

    const total = db.prepare(`SELECT COUNT(*) AS n FROM products ${whereSql}`).get(params).n;
    const rows = db
      .prepare(`SELECT * FROM products ${whereSql} ORDER BY ${orderSql} LIMIT @limit OFFSET @skip`)
      .all({ ...params, limit: safeLimit, skip: safeSkip });

    return {
      items: rows.map(toProduct),
      total,
      skip: safeSkip,
      limit: safeLimit,
      hasMore: safeSkip + rows.length < total,
    };
  },

  categories: () =>
    db.prepare('SELECT DISTINCT category FROM products WHERE category IS NOT NULL ORDER BY category').all()
      .map((r) => r.category),

  reviewsFor: (productId) =>
    db.prepare('SELECT * FROM reviews WHERE product_id = ? ORDER BY id').all(productId).map((r) => ({
      rating: r.rating,
      comment: r.comment,
      date: r.date,
      reviewerName: r.reviewer_name,
      reviewerEmail: r.reviewer_email,
    })),
};
