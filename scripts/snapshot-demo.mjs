// Records the running server's API (as each demo login) into app/assets/demo/snapshot.json for the
// standalone app (LocalBackend). Usage: node scripts/snapshot-demo.mjs  (server on :8787)
import { writeFileSync } from 'node:fs';
const BASE = process.env.API_BASE ?? 'http://localhost:8787';
const PHONES = ['9000000001', '9000000005', '9000000012', '9000000011',
  '9100000001', '9100000002', '9100000003', '9100000004', '9100000005', '9100000006'];

async function call(method, path, token, body) {
  const res = await fetch(BASE + path, {
    method, headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  return { status: res.status, data: text ? JSON.parse(text) : null };
}

const takenAt = new Date().toISOString();
const users = {};
const allUserIds = new Set(['jugaad_bot']);
let appKey = '';
for (const phone of PHONES) {
  const v = await call('POST', '/api/auth/verify', null, { phone, code: '1234' });
  if (v.status !== 200) { console.error('verify failed', phone, v.data); continue; }
  const tok = v.data.sessionToken;
  appKey = v.data.nexconn.appKey || appKey;
  const g = async (p) => { const r = await call('GET', p, tok); return r.status === 200 ? r.data : null; };
  const rec = { user: v.data.user, nexconn: { token: v.data.nexconn.token, userId: v.data.nexconn.userId }, get: {} };
  const put = async (p) => { const d = await g(p); if (d !== null) rec.get[p] = d; return d; };
  const me = await put('/api/me');
  const comms = await put('/api/communities');
  for (const c of comms ?? []) {
    await put(`/api/communities/${c.id}`);
    const bs = await put(`/api/communities/${c.id}/buckets?status=all`);
    for (const b of bs ?? []) {
      await put(`/api/buckets/${b.id}`);
      for (const s of b.shares ?? []) allUserIds.add(s.user.id);
      allUserIds.add(b.createdBy?.id);
    }
    if (me?.memberships?.some((m) => m.community.id === c.id && m.role === 'admin')) await put(`/api/admin/communities/${c.id}`);
  }
  const orders = await put('/api/me/orders');
  await put('/api/me/wallet');
  const vd = await put('/api/vendor/dashboard');
  const orderIds = new Set([...(orders ?? []).map((o) => o.id)]);
  for (const grp of vd?.packing ?? []) for (const l of grp.lines) orderIds.add(l.orderId);
  for (const b of vd?.buckets ?? []) if (b.orderId) orderIds.add(b.orderId);
  for (const id of orderIds) await put(`/api/orders/${id}`);
  users[phone] = rec;
  allUserIds.add(v.data.user.id);
  console.log(phone, v.data.user.name, Object.keys(rec.get).length, 'GETs', rec.nexconn.token ? 'token ok' : 'NO TOKEN');
}
// Chat profiles for everyone we know of (seed people, vendors, bot).
const any = users[PHONES[0]];
const v0 = await call('POST', '/api/auth/verify', null, { phone: PHONES[0], code: '1234' });
const ids = [...allUserIds].filter(Boolean);
for (const id of ['v_murugan', 'v_balaji', 'v_safehome', 'v_devgad', 'v_alnoor']) ids.push(id);
const prof = await call('GET', `/api/users?ids=${[...new Set(ids)].join(',')}`, v0.data.sessionToken);
writeFileSync(new URL('../app/assets/demo/snapshot.json', import.meta.url),
  JSON.stringify({ takenAt, appKey, profiles: prof.data, users }));
console.log('profiles', prof.data?.length, 'any', !!any);
