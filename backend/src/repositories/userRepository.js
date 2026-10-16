import { db, transaction } from '../db.js';

const toUser = (row) =>
  row && {
    id: row.id,
    username: row.username,
    email: row.email,
    firstName: row.first_name,
    lastName: row.last_name,
    gender: row.gender,
    image: row.image,
    lastLoginAt: row.last_login_at,
  };

const upsertUser = db.prepare(`
  INSERT INTO users (id, username, email, first_name, last_name, gender, image, last_login_at)
  VALUES (@id, @username, @email, @firstName, @lastName, @gender, @image, @lastLoginAt)
  ON CONFLICT(id) DO UPDATE SET
    username = excluded.username, email = excluded.email, first_name = excluded.first_name,
    last_name = excluded.last_name, gender = excluded.gender, image = excluded.image,
    last_login_at = COALESCE(excluded.last_login_at, users.last_login_at)
`);

export const userRepository = {
  /** Save (or refresh) a DummyJSON user. Pass `loggedIn` to stamp last_login_at. */
  save(user, { loggedIn = false } = {}) {
    upsertUser.run({
      id: user.id,
      username: user.username,
      email: user.email ?? null,
      firstName: user.firstName ?? null,
      lastName: user.lastName ?? null,
      gender: user.gender ?? null,
      image: user.image ?? null,
      lastLoginAt: loggedIn ? new Date().toISOString() : null,
    });
    return this.findById(user.id);
  },

  findById: (id) => toUser(db.prepare('SELECT * FROM users WHERE id = ?').get(id)),

  saveSession({ accessToken, refreshToken, userId }) {
    db.prepare(`
      INSERT INTO sessions (access_token, refresh_token, user_id) VALUES (?, ?, ?)
      ON CONFLICT(access_token) DO UPDATE SET refresh_token = excluded.refresh_token, user_id = excluded.user_id, revoked = 0
    `).run(accessToken, refreshToken ?? null, userId);
  },

  /** Returns { user, revoked } for a token we have seen, or null for an unknown token. */
  findSession(accessToken) {
    const row = db.prepare(`
      SELECT u.*, s.revoked FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.access_token = ?
    `).get(accessToken);
    return row ? { user: toUser(row), revoked: row.revoked === 1 } : null;
  },

  revokeSession: (accessToken) =>
    db.prepare('UPDATE sessions SET revoked = 1 WHERE access_token = ?').run(accessToken).changes > 0,

  /** Login = save user + session atomically. */
  saveLogin(payload) {
    return transaction(() => {
      const user = this.save(payload, { loggedIn: true });
      this.saveSession({ accessToken: payload.accessToken, refreshToken: payload.refreshToken, userId: payload.id });
      return user;
    });
  },
};
