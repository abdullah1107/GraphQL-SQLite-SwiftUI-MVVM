import 'dotenv/config';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

export const config = {
  port: Number(process.env.PORT ?? 4000),
  dummyJsonBaseUrl: (process.env.DUMMYJSON_BASE_URL ?? 'https://dummyjson.com').replace(/\/$/, ''),
  databaseFile: path.resolve(rootDir, process.env.DATABASE_FILE ?? './data/graphql-demo.db'),
  syncOnStart: (process.env.SYNC_ON_START ?? 'true').toLowerCase() !== 'false',
};
