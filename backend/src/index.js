import fs from 'node:fs';
import { ApolloServer } from '@apollo/server';
import { startStandaloneServer } from '@apollo/server/standalone';
import { config } from './config.js';
import { resolvers, buildContext } from './resolvers.js';
import { syncService } from './services/syncService.js';

const typeDefs = fs.readFileSync(new URL('./schema.graphql', import.meta.url), 'utf8');

const server = new ApolloServer({
  typeDefs,
  resolvers,
  introspection: true,
});

const { url } = await startStandaloneServer(server, {
  listen: { port: config.port, host: '0.0.0.0' },
  context: async ({ req }) => buildContext(req),
});

console.log(`🚀 GraphQL API ready at ${url}`);
console.log(`🗄️  SQLite database: ${config.databaseFile}`);

if (config.syncOnStart) {
  syncService
    .syncAll()
    .then((results) => results.forEach((r) => console.log(`✅ Synced ${r.count} ${r.entity} from DummyJSON`)))
    .catch((error) => console.warn(`⚠️  Initial sync failed: ${error.message} (queries will retry)`));
}
