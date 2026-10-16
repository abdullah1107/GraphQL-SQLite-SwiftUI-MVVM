import fs from 'node:fs';
import path from 'node:path';
import Database from 'better-sqlite3';
import { config } from './config.js';

fs.mkdirSync(path.dirname(config.databaseFile), { recursive: true });

export const db = new Database(config.databaseFile);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id            INTEGER PRIMARY KEY,
    username      TEXT NOT NULL UNIQUE,
    email         TEXT,
    first_name    TEXT,
    last_name     TEXT,
    gender        TEXT,
    image         TEXT,
    last_login_at TEXT
  );

  CREATE TABLE IF NOT EXISTS sessions (
    access_token  TEXT PRIMARY KEY,
    refresh_token TEXT,
    user_id       INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    revoked       INTEGER NOT NULL DEFAULT 0,   -- 1 after logout
    created_at    TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS products (
    id                     INTEGER PRIMARY KEY,
    title                  TEXT NOT NULL,
    description            TEXT,
    category               TEXT,
    price                  REAL NOT NULL,
    discount_percentage    REAL,
    rating                 REAL,
    stock                  INTEGER,
    brand                  TEXT,
    sku                    TEXT,
    weight                 REAL,
    warranty_information   TEXT,
    shipping_information   TEXT,
    availability_status    TEXT,
    return_policy          TEXT,
    minimum_order_quantity INTEGER,
    thumbnail              TEXT,
    tags                   TEXT NOT NULL DEFAULT '[]',  -- JSON array
    images                 TEXT NOT NULL DEFAULT '[]',  -- JSON array
    dimensions             TEXT,                        -- JSON object
    meta                   TEXT,                        -- JSON object
    synced_at              TEXT NOT NULL
  );
  CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);

  CREATE TABLE IF NOT EXISTS reviews (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id     INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    rating         INTEGER,
    comment        TEXT,
    date           TEXT,
    reviewer_name  TEXT,
    reviewer_email TEXT
  );
  CREATE INDEX IF NOT EXISTS idx_reviews_product ON reviews(product_id);

  CREATE TABLE IF NOT EXISTS carts (
    id               INTEGER PRIMARY KEY,
    user_id          INTEGER NOT NULL,
    total            REAL NOT NULL,
    discounted_total REAL NOT NULL,
    total_products   INTEGER NOT NULL,
    total_quantity   INTEGER NOT NULL,
    is_local         INTEGER NOT NULL DEFAULT 0,  -- 1 = created through this API, not from DummyJSON
    synced_at        TEXT NOT NULL
  );
  CREATE INDEX IF NOT EXISTS idx_carts_user ON carts(user_id);

  CREATE TABLE IF NOT EXISTS cart_items (
    cart_id             INTEGER NOT NULL REFERENCES carts(id) ON DELETE CASCADE,
    product_id          INTEGER NOT NULL,
    title               TEXT NOT NULL,
    price               REAL NOT NULL,
    quantity            INTEGER NOT NULL,
    total               REAL NOT NULL,
    discount_percentage REAL NOT NULL DEFAULT 0,
    discounted_total    REAL NOT NULL,
    thumbnail           TEXT,
    PRIMARY KEY (cart_id, product_id)
  );

  CREATE TABLE IF NOT EXISTS sync_log (
    entity      TEXT PRIMARY KEY,
    item_count  INTEGER NOT NULL,
    synced_at   TEXT NOT NULL
  );
`);

/** Run `fn` inside a single SQLite transaction. */
export const transaction = (fn) => db.transaction(fn)();
