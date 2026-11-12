// Boots the Jugaad Street API: store, Nexconn client, service, routes and the cutoff scheduler.
import url from 'node:url';
import { config, loadEnv } from './env.js';
import { Store } from './store.js';
import { createNexconn } from './nexconn.js';
import { JugaadService } from './service.js';
import { createApp } from './app.js';
import { reseed } from './seed.js';

export const SCHEDULER_MS = 30_000;

export async function start(overrides = {}) {
  loadEnv();
  const cfg = { ...config(), ...overrides };
  const logger = overrides.logger ?? console;
  const store = new Store(cfg.dataFile);
  const nx = createNexconn({ appKey: cfg.appKey, appSecret: cfg.appSecret, disabled: cfg.nexconnDisabled, logger });
  if (!nx.enabled) logger.warn('[nexconn] disabled (no keys in .env or NEXCONN_DISABLED=1); chat side effects are skipped');
  if (store.isEmpty) {
    logger.log('[seed] empty store: seeding demo data (first run)');
    const s = await reseed({ store, nx, logger });
    logger.log(`[seed] done: ${s.users} Nexconn users, ${s.cards} cards, groups: ${s.groups.join('; ') || 'none'}`);
  }
  const service = new JugaadService({ store, nx, logger, appKey: cfg.appKey });
  const app = createApp(service, { logger });

  const tick = () => {
    try {
      for (const r of service.runCutoffs()) logger.log(`[cutoff] ${r.bucketId} → ${r.result}`);
    } catch (e) { logger.error(`[cutoff] ${e.stack ?? e}`); }
  };
  tick();
  const timer = setInterval(tick, SCHEDULER_MS);
  timer.unref();

  const server = await new Promise((resolve) => { const s = app.listen(cfg.port, () => resolve(s)); });
  logger.log(`Jugaad Street API on http://localhost:${server.address().port} (nexconn: ${nx.enabled ? 'on' : 'off'})`);
  const stop = async () => { clearInterval(timer); await service.flush(); await new Promise((r) => server.close(r)); };
  return { app, server, service, store, nx, stop };
}

if (import.meta.url === url.pathToFileURL(process.argv[1] ?? '').href) {
  const { stop } = await start();
  const bye = async () => { await stop().catch(() => {}); process.exit(0); };
  process.on('SIGINT', bye);
  process.on('SIGTERM', bye);
}
