// npm run smoke: boots the API against real Nexconn on a COPY of the seeded DB, logs in as Ananya,
// joins the basmati bucket with 10 kg, authorises the hold, prints progress and reads the live card
// metadata back from Nexconn. Afterwards the card is restored to the main DB's state.
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { SERVER_DIR, config, loadEnv } from '../src/env.js';
import { Store } from '../src/store.js';
import { createNexconn } from '../src/nexconn.js';
import { JugaadService } from '../src/service.js';
import { reseed } from '../src/seed.js';

loadEnv();
const cfg = config();
const PORT = 8799;
const BASE = `http://127.0.0.1:${PORT}`;
const smokeDb = path.join(SERVER_DIR, 'data', 'smoke-db.json');
const nx = createNexconn({ appKey: cfg.appKey, appSecret: cfg.appSecret });
if (!nx.enabled) { console.error('Nexconn keys missing in .env'); process.exit(1); }

const main = new Store(cfg.dataFile);
if (main.isEmpty) {
  console.log('No seeded DB yet: running the seed first…');
  await reseed({ store: main, nx });
}
fs.copyFileSync(cfg.dataFile, smokeDb);

const logs = [];
const child = spawn(process.execPath, ['src/index.js'], {
  cwd: SERVER_DIR, env: { ...process.env, PORT: String(PORT), JUGAAD_DB: smokeDb }, stdio: ['ignore', 'pipe', 'pipe'],
});
child.stdout.on('data', (d) => logs.push(...String(d).trim().split('\n')));
child.stderr.on('data', (d) => logs.push(...String(d).trim().split('\n')));
const done = async (code) => { child.kill('SIGTERM'); fs.rmSync(smokeDb, { force: true }); process.exit(code); };

let token = null;
async function api(method, p, body) {
  const res = await fetch(BASE + p, {
    method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await res.json();
  if (!res.ok) throw new Error(`${method} ${p} → ${res.status} ${JSON.stringify(json)}`);
  return json;
}
const fmt = (p) => `${p.filled}/${p.target} kg · ${p.members} members · ₹${p.unitPrice}/kg · held ₹${p.held}`
  + (p.nextTier ? ` · ${p.nextTier.remaining} kg to ₹${p.nextTier.unitPrice}` : '');

try {
  for (let i = 0; ; i++) {
    try { await fetch(`${BASE}/api/health`); break; } catch { if (i > 50) throw new Error('server did not start'); await new Promise((r) => setTimeout(r, 200)); }
  }
  const health = await api('GET', '/api/health');
  console.log(`health: ${JSON.stringify(health)}`);
  await api('POST', '/api/auth/otp', { phone: '9000000001' });
  const v = await api('POST', '/api/auth/verify', { phone: '9000000001', code: '1234' });
  token = v.sessionToken;
  console.log(`login: ${v.user.name} (${v.user.id}), nexconn token ${v.nexconn.token ? 'issued' : 'MISSING'}, appKey ${v.nexconn.appKey}`);
  const before = await api('GET', '/api/buckets/b_basmati');
  console.log(`before: ${fmt(before.progress)}`);
  const j = await api('POST', '/api/buckets/b_basmati/shares', { qty: 10, payMode: 'hold' });
  console.log(`join:   share ${j.share.id} ${j.share.status}, hold ${j.share.hold.id} ₹${j.share.hold.amount} ${j.share.hold.status}`);
  const a = await api('POST', `/api/holds/${j.share.hold.id}/authorize`, { vpa: 'ananya@okaxis', pin: '1234' });
  console.log(`auth:   share ${a.share.status}, hold ${a.share.hold.status} via ${a.share.hold.vpa}`);
  console.log(`after:  ${fmt(a.bucket.progress)}`);
  console.log(`progress JSON: ${JSON.stringify(a.bucket.progress)}`);

  // Background Nexconn work (metadata + js:event) runs right after the response; give it a moment.
  await new Promise((r) => setTimeout(r, 2500));
  const meta = await nx.call('/v4/channel-type/message/metadata/list', { messageId: before.cardMessageId, page: 1 });
  // Live API returns an array of {key, value, updatedAt} (the docs show an object keyed by name).
  const raw = meta.result?.metadata ?? [];
  const kv = Array.isArray(raw) ? Object.fromEntries(raw.map((m) => [m.key, m.value])) : Object.fromEntries(Object.entries(raw).map(([k, m]) => [k, m.value]));
  const p = JSON.parse(kv.p);
  console.log(`live card ${before.cardMessageId} metadata from Nexconn: s=${kv.s} p.filled=${p.filled} p.held=${p.held}`);
  const nxLines = logs.filter((l) => l.includes('[nexconn]') || l.includes('[bg]'));
  console.log(nxLines.length ? `nexconn warnings:\n  ${nxLines.join('\n  ')}` : 'nexconn warnings: none');
  console.log(`server log:\n  ${logs.filter((l) => /^(GET|POST|DELETE) /.test(l)).join('\n  ')}`);
  const ok = p.filled === a.bucket.progress.filled;
  console.log(ok ? 'SMOKE OK' : 'SMOKE FAILED: card metadata does not match');

  // Put the real card back to the main DB's state (the smoke ran on a copy).
  const svc = new JugaadService({ store: main, nx });
  await nx.updateCard(svc.bucketView(main.bucket('b_basmati')));
  console.log('restored the basmati card metadata to the main DB state');
  await done(ok ? 0 : 1);
} catch (e) {
  console.error(`SMOKE FAILED: ${e.message}`);
  console.error(logs.slice(-20).join('\n'));
  await done(1);
}
