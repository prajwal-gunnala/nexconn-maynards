import { Store, emptyDb } from '../src/store.js';
import { JugaadService } from '../src/service.js';

/** Nexconn double: records every helper call, returns fake ids. */
export function mockNexconn() {
  const calls = [];
  let n = 0;
  const rec = (name, ret) => async (...args) => { calls.push({ name, args }); return typeof ret === 'function' ? ret(...args) : ret; };
  return {
    enabled: true,
    calls,
    named: (name) => calls.filter((c) => c.name === name),
    ensureUser: rec('ensureUser', (id) => `tok_${id}`),
    ensureStreet: rec('ensureStreet', { created: true }),
    addToStreet: rec('addToStreet', true),
    postBucketCard: rec('postBucketCard', () => `MSG-${++n}`),
    updateCard: rec('updateCard', true),
    postEvent: rec('postEvent', () => `EVT-${++n}`),
    createBucketGroup: rec('createBucketGroup', { created: true }),
    postOrder: rec('postOrder', () => `ORD-${++n}`),
    sendOtp: rec('sendOtp', () => `OTP-${++n}`),
    sendText: rec('sendText', () => `TXT-${++n}`),
    health: async () => 'ok',
  };
}

export const T0 = new Date('2026-11-13T04:00:00.000Z'); // Fri 9:30 am IST

/** Service on an in-memory store with a community, members and a vendor. Clock is controllable. */
export function setup() {
  const store = new Store(null, emptyDb());
  const nx = mockNexconn();
  const clock = { now: new Date(T0) };
  let seed = 42;
  const rng = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
  const svc = new JugaadService({ store, nx, now: () => clock.now, rng, logger: { warn() {}, log() {}, error() {} } });
  store.data.communities.c_test = { id: 'c_test', name: 'Test Towers', kind: 'society', area: 'OMR', city: 'Chennai', flats: 100 };
  const people = ['ananya', 'ravi', 'meera', 'kiran', 'priya', 'arjun', 'sunita', 'lakshmi'];
  people.forEach((p, i) => {
    store.putUser({ id: `u_${p}`, name: p[0].toUpperCase() + p.slice(1), phone: `900000000${i + 1}`, kind: 'member' });
    store.addMembership({ userId: `u_${p}`, communityId: 'c_test', unit: `A-${101 + i}`, role: p === 'priya' ? 'admin' : 'member' });
  });
  store.putUser({ id: 'v_fish', name: 'Fish Stall', phone: '9000000011', kind: 'vendor', vendorId: 'v_fish' });
  store.data.vendors.v_fish = { id: 'v_fish', name: 'Fish Stall', place: 'Kasimedu', rating: 4.8, userId: 'v_fish' };
  const u = (p) => store.user(`u_${p}`);
  const later = (h = 6) => new Date(clock.now.getTime() + h * 3600_000).toISOString();
  const create = (by, draft) => svc.createBucket(u(by), { communityId: 'c_test', vendorId: 'v_fish', cutoffAt: later(), ...draft });
  /** join + authorize (hold) or book (at_market) */
  const take = (who, bucketId, req) => {
    const r = svc.joinBucket(u(who), bucketId, req);
    if (r.share.hold) return svc.authorizeHold(u(who), r.share.hold.id, { vpa: `${who}@okaxis`, pin: '1234' });
    return r;
  };
  return { store, nx, svc, clock, u, create, take, later };
}

export const SPLIT = {
  type: 'split', category: 'fish', title: 'Whole Seer', unitLabel: 'cut', retailUnitPrice: 1400, unitPrice: 950,
  units: [
    { id: 'head', label: 'Head', grams: 600, price: 420 },
    { id: 's1', label: 'Steak 1', grams: 650, price: 680 },
    { id: 's2', label: 'Steak 2', grams: 650, price: 680 },
    { id: 'tail', label: 'Tail', grams: 550, price: 420 },
  ],
};
export const BULK = {
  type: 'bulk', category: 'grocery', title: 'Basmati', unitLabel: 'kg', retailUnitPrice: 135, minQty: 5, maxQty: 50,
  tiers: [{ minQty: 25, unitPrice: 96 }, { minQty: 100, unitPrice: 88 }],
};
export const TRIP = {
  type: 'trip', category: 'veg', title: 'Koyambedu run', capacity: 100, minLoadKg: 40, transportFee: 1000,
  items: [
    { id: 'onion', name: 'Onion', unit: 'kg', price: 28, retailPrice: 45 },
    { id: 'coconut', name: 'Coconut', unit: 'pc', price: 22, kgPerUnit: 0.5, retailPrice: 38 },
  ],
};
