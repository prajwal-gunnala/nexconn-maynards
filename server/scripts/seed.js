// npm run seed: reset server/data/db.json to the demo seed and push it into Nexconn.
// Stop the API first (or restart it afterwards): a running server keeps its own copy in memory.
import { config, loadEnv } from '../src/env.js';
import { Store } from '../src/store.js';
import { createNexconn } from '../src/nexconn.js';
import { reseed } from '../src/seed.js';

loadEnv();
const cfg = config();
const store = new Store(cfg.dataFile);
const nx = createNexconn({ appKey: cfg.appKey, appSecret: cfg.appSecret, disabled: cfg.nexconnDisabled });
const t0 = Date.now();
const s = await reseed({ store, nx });
const d = store.data;
console.log(`Seeded ${Object.keys(d.users).length} users, ${Object.keys(d.buckets).length} buckets `
  + `(${Object.values(d.buckets).filter((b) => b.status === 'live').length} live), ${Object.keys(d.orders).length} past orders.`);
console.log(`Nexconn: ${s.users} tokens, ${s.cards} cards, ${s.texts} texts; ${s.groups.join('; ') || 'no groups'} (${((Date.now() - t0) / 1000).toFixed(1)} s)`);
console.log('Restart the API if it is running.');
