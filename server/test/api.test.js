// HTTP layer against the seeded data (Nexconn mocked), plus the Nexconn client with fetch mocked.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { createApp } from '../src/app.js';
import { Store } from '../src/store.js';
import { JugaadService } from '../src/service.js';
import { buildSeed } from '../src/seed.js';
import { cardMetadata, createNexconn } from '../src/nexconn.js';
import { mockNexconn } from './helpers.js';

async function boot() {
  const store = new Store(null, buildSeed(new Date()));
  const nx = mockNexconn();
  const svc = new JugaadService({ store, nx, appKey: 'appkey', logger: { warn() {}, log() {}, error() {} } });
  const server = createApp(svc, { log: false }).listen(0);
  await new Promise((r) => server.once('listening', r));
  const base = `http://127.0.0.1:${server.address().port}`;
  let token = null;
  const call = async (method, path, body) => {
    const res = await fetch(base + path, {
      method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      body: body ? JSON.stringify(body) : undefined,
    });
    return { status: res.status, body: await res.json().catch(() => null) };
  };
  return { store, nx, svc, server, call, login: (t) => { token = t; } };
}

test('API: login, browse, join basmati, authorize, wallet', async (t) => {
  const { server, call, login, svc } = await boot();
  t.after(() => server.close());

  assert.deepEqual((await call('POST', '/api/auth/otp', { phone: '9000000001' })).body, { ok: true, devCode: '1234' });
  assert.equal((await call('POST', '/api/auth/verify', { phone: '9000000001', code: '0000' })).body.error.code, 'OTP_INVALID');
  assert.equal((await call('POST', '/api/auth/verify', { phone: '9999999999', code: '1234' })).body.error.code, 'NAME_REQUIRED');
  const v = await call('POST', '/api/auth/verify', { phone: '+91 90000 00001', code: '1234' });
  assert.equal(v.status, 200);
  assert.equal(v.body.user.id, 'u_ananya');
  assert.match(v.body.sessionToken, /^[0-9a-f]{64}$/);
  assert.deepEqual(v.body.nexconn, { appKey: 'appkey', token: 'tok_u_ananya', userId: 'u_ananya' });

  assert.equal((await call('GET', '/api/me')).status, 401);
  login(v.body.sessionToken);
  const me = await call('GET', '/api/me');
  assert.equal(me.body.memberships[0].unit, 'B-1204');
  assert.equal(me.body.memberships[0].community.stats.liveBuckets, 7);

  const live = await call('GET', '/api/communities/c_seabreeze/buckets?status=live');
  assert.equal(live.body.length, 7);
  assert.ok(live.body.every((b) => b.status === 'live'));
  const seer = live.body.find((b) => b.id === 'b_seer');
  assert.deepEqual([seer.progress.filled, seer.progress.target], [6, 8]);
  assert.equal(seer.units.filter((u) => !u.owner).map((u) => u.id).join(), 's2,tail');

  const j = await call('POST', '/api/buckets/b_basmati/shares', { qty: 10, payMode: 'hold' });
  assert.equal(j.status, 200);
  assert.deepEqual([j.body.share.status, j.body.share.hold.status, j.body.share.hold.amount], ['pending_payment', 'created', 960]);
  const bad = await call('POST', `/api/holds/${j.body.share.hold.id}/authorize`, { vpa: 'ananya@okaxis', pin: '0000' });
  assert.deepEqual([bad.status, bad.body.error.code], [400, 'PIN_INCORRECT']);
  const ok = await call('POST', `/api/holds/${j.body.share.hold.id}/authorize`, { vpa: 'ananya@okaxis', pin: '1234' });
  assert.equal(ok.body.share.status, 'held');
  assert.equal(ok.body.bucket.progress.filled, 92);
  assert.equal(ok.body.bucket.myShare.id, j.body.share.id);

  const w = await call('GET', '/api/me/wallet');
  assert.equal(w.body.heldNow, 480 + 960);
  assert.equal((await call('GET', '/api/buckets/nope')).body.error.code, 'NOT_FOUND');
  assert.equal((await call('GET', '/api/nope')).status, 404);
  assert.equal((await call('GET', '/api/health')).body.nexconn, 'ok');
  const orders = await call('GET', '/api/me/orders');
  assert.equal(orders.body.length, 2);
  await svc.flush();
});

test('API: new user joins a community, creates a bucket, demo close', async (t) => {
  const { server, call, login, svc, nx } = await boot();
  t.after(() => server.close());
  const v = await call('POST', '/api/auth/verify', { phone: '9123456780', code: '1234', name: 'Nisha' });
  login(v.body.sessionToken);
  assert.equal((await call('POST', '/api/buckets', { communityId: 'c_palmgrove', type: 'bulk', title: 'x' })).body.error.code, 'NOT_MEMBER');
  const m = await call('POST', '/api/communities/c_palmgrove/join', { unit: 'pg-504' });
  assert.equal(m.body.membership.unit, 'PG-504');
  const created = await call('POST', '/api/buckets', {
    communityId: 'c_palmgrove', type: 'bulk', category: 'grocery', title: 'Cold-pressed groundnut oil', unitLabel: 'L',
    tiers: [{ minQty: 10, unitPrice: 240 }], retailUnitPrice: 320, cutoffAt: new Date(Date.now() + 3600_000).toISOString(),
  });
  assert.equal(created.status, 200);
  await call('POST', `/api/buckets/${created.body.id}/shares`, { qty: 4, payMode: 'hold' });
  const closed = await call('POST', `/api/buckets/${created.body.id}/close`);
  assert.equal(closed.body.bucket.status, 'expired');
  await svc.flush();
  assert.deepEqual(nx.named('addToStreet')[0].args, ['c_palmgrove', [v.body.user.id]]);
  assert.equal(nx.named('postBucketCard').length, 1);
});

test('Nexconn client: signing, backup host retry, card metadata', async () => {
  const seen = [];
  const fetchImpl = async (url, init) => {
    seen.push({ url, headers: init.headers, body: JSON.parse(init.body) });
    if (url.startsWith('https://a')) return new Response('bad gateway', { status: 502 });
    return new Response(JSON.stringify({ code: 0, result: { messageIds: [{ messageId: 'M-1' }] } }), { status: 200 });
  };
  const nx = createNexconn({ appKey: 'k', appSecret: 's3cret', hosts: ['https://a.test', 'https://b.test'], fetchImpl, logger: { warn() {} } });
  const view = {
    id: 'b_seer', communityId: 'c_x', type: 'split', title: 'Seer', subtitle: '', image: 'seer', vendor: { name: 'Murugan' },
    cutoffAt: '2026-11-13T00:00:00Z', unitLabel: 'cut', status: 'live', progress: { filled: 1, target: 2 },
    units: [{ id: 'head', owner: { name: 'sunita' } }, { id: 'tail', owner: null }],
  };
  assert.equal(await nx.postBucketCard(view), 'M-1');
  assert.deepEqual(seen.map((s) => s.url), ['https://a.test/v4/group-channel/message/send', 'https://b.test/v4/group-channel/message/send']);
  const { headers, body } = seen[1];
  assert.equal(headers.Signature, crypto.createHash('sha1').update(`s3cret${headers.Nonce}${headers.Timestamp}`).digest('hex'));
  assert.equal(headers['App-Key'], 'k');
  assert.deepEqual([body.fromUserId, body.toChannelIds, body.messageType, body.hasMetadata], ['jugaad_bot', ['street_c_x'], 'js:bucket', true]);
  const content = JSON.parse(body.content);
  assert.ok(Object.values(content).every((x) => typeof x === 'string'));
  assert.equal(content.vendor, 'Murugan');
  assert.deepEqual(body.metadata, cardMetadata(view));
  assert.deepEqual(JSON.parse(body.metadata.u), [['head', 'S'], ['tail', '']]);
  assert.equal(nx.state.status, 'ok');

  const down = createNexconn({ appKey: 'k', appSecret: 's', hosts: ['https://a.test'], fetchImpl: async () => { throw new TypeError('fetch failed'); }, logger: { warn() {} } });
  assert.equal(await down.postEvent('g', { bucketId: 'b', kind: 'joined', text: 't', actor: 'u' }), null);
  assert.equal(down.state.status, 'error');
  assert.equal(await createNexconn({}).ensureUser('u', 'U'), null, 'no keys → disabled no-op');
});
