// npm run reset-db — delete the SQLite file so the next start re-creates and re-syncs it.
import fs from 'node:fs';
import { config } from '../src/config.js';

for (const suffix of ['', '-wal', '-shm']) {
  fs.rmSync(config.databaseFile + suffix, { force: true });
}
console.log(`🗑️  Removed ${config.databaseFile}`);
