// npm run sync — pull every product and cart from DummyJSON into SQLite, then exit.
import { syncService } from '../src/services/syncService.js';
import { config } from '../src/config.js';

try {
  const results = await syncService.syncAll();
  for (const r of results) console.log(`✅ ${r.entity}: ${r.count} rows saved`);
  console.log(`Database: ${config.databaseFile}`);
} catch (error) {
  console.error(`❌ Sync failed: ${error.message}`);
  process.exitCode = 1;
}
