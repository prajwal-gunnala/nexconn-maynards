// Seed data (docs/CONTRACT.md "Seed"): Chennai societies, people, vendors, live + past buckets,
// built through the real service code so every amount, hold and order is consistent.
import { Store, emptyDb } from './store.js';
import { JugaadService } from './service.js';
import { BOT_ID, BOT_NAME, bucketGroupId, createNexconn, streetGroupId } from './nexconn.js';

const IST = 330 * 60_000;
const MIN = 60_000;
const HOUR = 60 * MIN;
const DAY = 24 * HOUR;

/** IST wall-clock time `off` days after the IST date of `d`. */
const istAt = (d, off, h, m = 0) => {
  const x = new Date(d.getTime() + IST);
  return new Date(Date.UTC(x.getUTCFullYear(), x.getUTCMonth(), x.getUTCDate() + off, h, m) - IST);
};
const istDow = (d) => new Date(d.getTime() + IST).getUTCDay();
const roundUp = (d, mins = 30) => new Date(Math.ceil(d.getTime() / (mins * MIN)) * mins * MIN);
/** Next given weekday (0=Sun) at h:m IST that is at least `ahead` ms away. */
function nextDow(now, dow, h, m = 0, ahead = 3 * HOUR) {
  for (let off = 0; off < 15; off++) {
    const c = istAt(now, off, h, m);
    if (istDow(c) === dow && c - now >= ahead) return c;
  }
  throw new Error('unreachable');
}
/** Next daily h:m IST at least `ahead` away. */
function nextDaily(now, h, m = 0, ahead = 4 * HOUR) {
  for (let off = 0; off < 3; off++) { const c = istAt(now, off, h, m); if (c - now >= ahead) return c; }
  throw new Error('unreachable');
}

export const PEOPLE = [
  { id: 'u_ananya', name: 'Ananya', phone: '9000000001', unit: 'B-1204' },
  { id: 'u_ravi', name: 'Ravi', phone: '9000000002', unit: 'C-801' },
  { id: 'u_meera', name: 'Meera', phone: '9000000003', unit: 'A-303' },
  { id: 'u_kiran', name: 'Kiran', phone: '9000000004', unit: 'B-402' },
  { id: 'u_priya', name: 'Priya', phone: '9000000005', unit: 'A-1101', role: 'admin' },
  { id: 'u_arjun', name: 'Arjun', phone: '9000000006', unit: 'B-702' },
  { id: 'u_sunita', name: 'Sunita', phone: '9000000007', unit: 'A-201' },
];

export const VENDORS = [
  { id: 'v_murugan', name: 'Murugan Fish Stall', place: 'Kasimedu Harbour', rating: 4.8, phone: '9000000011', category: 'fish' },
  { id: 'v_balaji', name: 'Sri Balaji Traders', place: 'Koyambedu Market', rating: 4.6, phone: '9000000012', category: 'grocery' },
  { id: 'v_safehome', name: 'SafeHome Pest Services', place: 'Thoraipakkam', rating: 4.5, phone: '9000000013', category: 'service' },
  { id: 'v_devgad', name: 'Devgad Mango FPO', place: 'Devgad, Maharashtra', rating: 4.9, phone: '9000000014', category: 'fruit' },
  { id: 'v_alnoor', name: 'Al-Noor Meats', place: 'Pallavaram', rating: 4.7, phone: '9000000015', category: 'meat' },
];

// Neighbours without app logins (they make the numbers real: 31 flats, 186 kg, …).
const NEIGHBOUR_NAMES = ['Lakshmi', 'Farhan', 'Deepa', 'Venkat', 'Sanjay', 'Kavya', 'Rahul', 'Divya', 'Harish', 'Nandini',
  'Suresh', 'Revathi', 'Aditya', 'Fatima', 'Gopal', 'Swathi', 'Manoj', 'Anjali', 'Karthik', 'Pooja', 'Vikram', 'Shalini',
  'Rajesh', 'Bhavana', 'Imran', 'Keerthi', 'Naveen', 'Sneha', 'Ramesh', 'Uma'];
const PALM_NAMES = ['Gayathri', 'Mohan', 'Zoya', 'Senthil'];
const flat = (i) => `${'ABCD'[i % 4]}-${(Math.floor(i * 7 / 4) % 15) + 1}${String((i % 4) + 1).padStart(2, '0')}`;
export const NEIGHBOURS = NEIGHBOUR_NAMES.map((name, i) => ({ id: `n_${name.toLowerCase()}`, name, unit: flat(i + 3) }));
const PALM = PALM_NAMES.map((name, i) => ({ id: `n_${name.toLowerCase()}`, name, unit: `PG-${i + 2}0${i + 1}` }));

const COMMUNITIES = [
  {
    id: 'c_seabreeze', name: 'Sea Breeze Towers', kind: 'society', area: 'OMR, Thoraipakkam', city: 'Chennai', flats: 412,
    image: 'seabreeze', baseMembers: 248, baseSavedThisMonth: 38650,
    pendingVendors: [
      { id: 'pv_kumar', name: 'Kumar Organic Greens', category: 'veg', place: 'Thiruporur', note: 'Leafy greens from a Thiruporur farm, twice a week' },
      { id: 'pv_amma', name: "Amma's Podi & Pickles", category: 'home foods', place: 'Velachery', note: 'Home kitchen, FSSAI registered' },
    ],
  },
  {
    id: 'c_palmgrove', name: 'Palm Grove Apartments', kind: 'society', area: 'Sholinganallur', city: 'Chennai', flats: 186,
    image: 'palmgrove', baseMembers: 97, baseSavedThisMonth: 12400, pendingVendors: [],
  },
];

/** Builds the full seed DB in memory (no Nexconn calls). `now` = real current time. */
export function buildSeed(now = new Date(), { rng = Math.random } = {}) {
  const store = new Store(null, emptyDb());
  let clock = new Date(now);
  const svc = new JugaadService({ store, nx: createNexconn({ disabled: true }), now: () => clock, rng, logger: { warn() {}, log() {} } });
  const at = (d) => { clock = new Date(d); };
  const iso = (d) => new Date(d).toISOString();

  // people, vendors, communities, memberships
  const created = iso(now.getTime() - 60 * DAY);
  for (const p of PEOPLE) store.putUser({ id: p.id, name: p.name, phone: p.phone, kind: 'member', createdAt: created });
  for (const n of [...NEIGHBOURS, ...PALM]) store.putUser({ id: n.id, name: n.name, phone: null, kind: 'member', createdAt: created });
  for (const v of VENDORS) {
    store.putUser({ id: v.id, name: v.name, phone: v.phone, kind: 'vendor', vendorId: v.id, createdAt: created });
    store.data.vendors[v.id] = { id: v.id, name: v.name, place: v.place, rating: v.rating, category: v.category, userId: v.id };
  }
  for (const c of COMMUNITIES) store.data.communities[c.id] = { ...c, createdAt: created };
  for (const p of [...PEOPLE, ...NEIGHBOURS]) {
    store.addMembership({ userId: p.id, communityId: 'c_seabreeze', unit: p.unit, role: p.role ?? 'member', joinedAt: created });
  }
  for (const p of PALM) store.addMembership({ userId: p.id, communityId: 'c_palmgrove', unit: p.unit, role: 'member', joinedAt: created });

  const user = (id) => store.user(id);
  const n = (name) => `n_${name.toLowerCase()}`;
  /** Create a bucket at time `from`, then add claims spread evenly until `to`. */
  function bucket(draft, by, from, to, claims) {
    at(from);
    const b = svc.createBucket(user(by), { communityId: 'c_seabreeze', ...draft }, { post: false });
    claims.forEach(([uid, req], i) => {
      at(from.getTime() + ((to - from) * (i + 1)) / (claims.length + 1));
      const { share } = svc.joinBucket(user(uid), b.id, req);
      if (share.hold) svc.authorizeHold(user(uid), share.hold.id, { vpa: `${user(uid).name.toLowerCase()}@okaxis`, pin: '1234' });
    });
    return store.bucket(b.id);
  }
  const cutOpt = (cut) => ({ options: { cut } });

  // ---- past buckets (wallet history for Ananya) -------------------------------------------
  const prawnCut = istAt(now, -5, 8, 30);
  bucket({
    id: 'b_past_prawns', type: 'bulk', category: 'fish', title: 'Kasimedu Tiger Prawns', subtitle: 'Morning catch, cleaned and deveined',
    image: 'prawns', vendorId: 'v_murugan', unitLabel: 'kg', tiers: [{ minQty: 5, unitPrice: 520 }, { minQty: 10, unitPrice: 480 }],
    retailUnitPrice: 700, minQty: 1, maxQty: 5, cutoffAt: iso(prawnCut), deliverAt: iso(prawnCut.getTime() + 2 * HOUR), pickupPoint: 'Gate 2',
  }, 'u_ravi', new Date(prawnCut - 14 * HOUR), new Date(prawnCut - HOUR),
  [['u_ravi', { qty: 3 }], ['u_ananya', { qty: 2 }], ['u_meera', { qty: 2 }], ['u_kiran', { qty: 3 }], ['u_sunita', { qty: 2 }]]);
  at(prawnCut); svc.closeBucket('b_past_prawns');

  const bananaCut = istAt(now, -19, 9, 0);
  bucket({
    id: 'b_past_banana', type: 'bulk', category: 'fruit', title: 'Nendran Banana Bunches', subtitle: 'Straight from a Theni farm',
    image: 'banana', vendorId: 'v_balaji', unitLabel: 'dozen', tiers: [{ minQty: 10, unitPrice: 60 }, { minQty: 20, unitPrice: 52 }],
    retailUnitPrice: 80, minQty: 1, maxQty: 6, cutoffAt: iso(bananaCut), deliverAt: iso(bananaCut.getTime() + 3 * HOUR), pickupPoint: 'Clubhouse',
  }, 'u_meera', new Date(bananaCut - 20 * HOUR), new Date(bananaCut - HOUR),
  [['u_ananya', { qty: 3 }], [n('Lakshmi'), { qty: 4 }], [n('Deepa'), { qty: 4 }], [n('Kavya'), { qty: 4 }], [n('Rahul'), { qty: 4 }], [n('Uma'), { qty: 4 }]]);
  at(bananaCut); svc.closeBucket('b_past_banana');

  for (const [oid, vendorId, hours] of [['b_past_prawns', 'v_murugan', 2], ['b_past_banana', 'v_balaji', 3]]) {
    const o = store.order(store.bucket(oid).orderId);
    at(new Date(o.createdAt).getTime() + hours * HOUR);
    for (const l of o.lines) svc.handover(user(vendorId), o.id, { otp: l.otp });
  }

  const crabCut = istAt(now, -3, 19, 0);
  bucket({
    id: 'b_past_crab', type: 'split', category: 'fish', title: 'Pulicat Mud Crabs (4)', subtitle: 'Live crabs, about 500 g each',
    image: 'crab', vendorId: 'v_murugan', unitLabel: 'crab', retailUnitPrice: 1500, unitPrice: 1200,
    units: [1, 2, 3, 4].map((i) => ({ id: `c${i}`, label: `Crab ${i}`, grams: 500, price: 600 })),
    cutoffAt: iso(crabCut), deliverAt: iso(crabCut.getTime() + 13 * HOUR), pickupPoint: 'Gate 2',
  }, 'u_ravi', new Date(crabCut - 8 * HOUR), new Date(crabCut - HOUR),
  [['u_ananya', { unitIds: ['c1'] }], ['u_ravi', { unitIds: ['c2'] }]]);
  at(crabCut); svc.closeBucket('b_past_crab');

  // ---- live buckets ------------------------------------------------------------------------
  const ago = (h) => new Date(now.getTime() - h * HOUR);
  const soon = new Date(now.getTime() - 5 * MIN);

  const seerCut = roundUp(new Date(now.getTime() + 3 * HOUR));
  bucket({
    id: 'b_seer', type: 'split', category: 'fish', title: 'Whole Seer (Vanjaram)', subtitle: 'Landed 6:10 am at Kasimedu',
    image: 'seer', vendorId: 'v_murugan', unitLabel: 'cut', retailUnitPrice: 1400, unitPrice: 950,
    netWeight: '5.2 kg', serves: '8 families', cutoffAt: iso(seerCut), deliverAt: iso(seerCut.getTime() + 90 * MIN), pickupPoint: 'Gate 2',
    description: 'One whole seer, cleaned at the harbour and cut to your order. Head is great for kuzhambu; the middle steaks fry best.',
    units: [
      { id: 'head', label: 'Head', grams: 600, price: 420 },
      { id: 's1', label: 'Steak 1', grams: 650, price: 680 },
      { id: 's2', label: 'Steak 2', grams: 650, price: 680 },
      { id: 's3', label: 'Steak 3', grams: 650, price: 680 },
      { id: 's4', label: 'Steak 4', grams: 650, price: 680 },
      { id: 's5', label: 'Steak 5', grams: 600, price: 620 },
      { id: 's6', label: 'Steak 6', grams: 600, price: 600 },
      { id: 'tail', label: 'Tail', grams: 550, price: 420 },
    ],
    optionGroups: [{ key: 'cut', label: 'How should Murugan cut it?', choices: ['Curry cut', 'Fry slices', 'Steaks', 'Whole'] }],
  }, 'u_ravi', ago(5), soon, [
    ['u_ravi', { unitIds: ['s1'], ...cutOpt('Steaks') }], ['u_sunita', { unitIds: ['head'], ...cutOpt('Curry cut') }],
    ['u_meera', { unitIds: ['s3'], ...cutOpt('Curry cut') }], ['u_kiran', { unitIds: ['s4'], ...cutOpt('Fry slices') }],
    ['u_priya', { unitIds: ['s5'], ...cutOpt('Steaks') }], ['u_arjun', { unitIds: ['s6'], ...cutOpt('Fry slices') }],
  ]);

  const riceCut = nextDaily(now, 20, 0);
  bucket({
    id: 'b_basmati', type: 'bulk', category: 'grocery', title: 'Aged Basmati Rice (1121)', subtitle: 'Koyambedu wholesale, packed in 5 kg bags',
    image: 'basmati', vendorId: 'v_balaji', unitLabel: 'kg', tiers: [{ minQty: 25, unitPrice: 96 }, { minQty: 100, unitPrice: 88 }],
    retailUnitPrice: 135, minQty: 5, maxQty: 50, netWeight: '5 kg bags', cutoffAt: iso(riceCut),
    deliverAt: iso(istAt(riceCut, 1, 10, 0)), pickupPoint: 'Clubhouse',
    description: 'Two-year aged 1121 basmati. Everyone pays the tier price reached at the cutoff.',
  }, 'u_meera', ago(26), soon, [
    ['u_meera', { qty: 15 }], ['u_ravi', { qty: 20 }], ['u_kiran', { qty: 10 }],
    ['u_priya', { qty: 12 }], ['u_arjun', { qty: 15 }], ['u_sunita', { qty: 10 }],
  ]);

  const pestCut = nextDow(now, 0, 18, 0);
  const pestClaims = [['u_priya', { qty: 1 }], ['u_ravi', { qty: 1 }], ['u_meera', { qty: 1 }], ['u_kiran', { qty: 1 }],
    ['u_arjun', { qty: 1 }], ...NEIGHBOURS.slice(0, 25).map((x) => [x.id, { qty: 1 }])];
  pestClaims.splice(17, 0, ['u_ananya', { qty: 1 }]);
  bucket({
    id: 'b_pest', type: 'service', category: 'service', title: 'Society Pest Control (Gel + Spray)', subtitle: 'Cockroach and ant treatment, 90-day warranty',
    image: 'pest', vendorId: 'v_safehome', unitLabel: 'flat', tiers: [{ minQty: 10, unitPrice: 480 }, { minQty: 25, unitPrice: 400 }, { minQty: 50, unitPrice: 340 }],
    retailUnitPrice: 650, minQty: 1, maxQty: 1, cutoffAt: iso(pestCut), deliverAt: iso(istAt(pestCut, 6, 10, 0)), pickupPoint: 'Your flat',
    description: 'Same price for 2BHK and 3BHK. SafeHome covers all blocks on one Saturday, odourless gel in kitchens.',
  }, 'u_priya', ago(50), soon, pestClaims);

  const tripCut = nextDow(now, 6, 5, 0);
  bucket({
    id: 'b_trip', type: 'trip', category: 'veg', title: 'Koyambedu Saturday Run', subtitle: "Arjun's tempo, wholesale veg and fruit, back by 9 am",
    image: 'koyambedu', vendorId: 'v_balaji', unitLabel: 'kg', capacity: 300, minLoadKg: 150, transportFee: 1800,
    cutoffAt: iso(tripCut), deliverAt: iso(tripCut.getTime() + 4 * HOUR), pickupPoint: 'Basement B2',
    description: 'Tempo and driver cost ₹1,800, shared by weight. The more we load, the less each kg costs.',
    items: [
      { id: 'onion', name: 'Onion', unit: 'kg', price: 28, retailPrice: 45 },
      { id: 'tomato', name: 'Tomato', unit: 'kg', price: 22, retailPrice: 40 },
      { id: 'potato', name: 'Potato', unit: 'kg', price: 30, retailPrice: 42 },
      { id: 'carrot', name: 'Carrot (Ooty)', unit: 'kg', price: 40, retailPrice: 70 },
      { id: 'beans', name: 'Beans', unit: 'kg', price: 50, retailPrice: 90 },
      { id: 'banana', name: 'Banana (Poovan)', unit: 'dozen', price: 45, kgPerUnit: 1.5, retailPrice: 70 },
      { id: 'coconut', name: 'Coconut', unit: 'pc', price: 22, kgPerUnit: 0.5, retailPrice: 38 },
    ],
  }, 'u_arjun', ago(30), soon, [
    ['u_arjun', { items: [{ id: 'onion', qty: 15 }, { id: 'potato', qty: 10 }, { id: 'beans', qty: 2 }, { id: 'coconut', qty: 6 }] }],
    ['u_kiran', { items: [{ id: 'onion', qty: 10 }, { id: 'tomato', qty: 5 }, { id: 'potato', qty: 5 }] }],
    ['u_sunita', { items: [{ id: 'tomato', qty: 6 }, { id: 'carrot', qty: 3 }, { id: 'banana', qty: 2 }] }],
    [n('Lakshmi'), { items: [{ id: 'onion', qty: 10 }, { id: 'tomato', qty: 5 }] }],
    [n('Venkat'), { items: [{ id: 'potato', qty: 10 }, { id: 'onion', qty: 5 }] }],
    [n('Deepa'), { items: [{ id: 'beans', qty: 3 }, { id: 'carrot', qty: 4 }, { id: 'tomato', qty: 5 }] }],
    [n('Sanjay'), { items: [{ id: 'onion', qty: 8 }, { id: 'coconut', qty: 10 }] }],
    [n('Kavya'), { items: [{ id: 'banana', qty: 4 }, { id: 'tomato', qty: 4 }] }],
    [n('Harish'), { items: [{ id: 'onion', qty: 10 }, { id: 'potato', qty: 5 }] }],
    [n('Nandini'), { items: [{ id: 'carrot', qty: 5 }, { id: 'beans', qty: 3 }] }],
    [n('Suresh'), { items: [{ id: 'onion', qty: 6 }, { id: 'tomato', qty: 6 }] }],
    [n('Revathi'), { items: [{ id: 'potato', qty: 8 }, { id: 'banana', qty: 2 }] }],
    [n('Gopal'), { items: [{ id: 'onion', qty: 5 }, { id: 'tomato', qty: 3 }] }],
    [n('Swathi'), { items: [{ id: 'tomato', qty: 5 }] }],
  ]);

  const mangoCut = roundUp(new Date(now.getTime() + 26 * HOUR), 60);
  bucket({
    id: 'b_alphonso', type: 'bulk', category: 'fruit', title: 'Devgad Alphonso Peti', subtitle: 'GI-tagged, farm-direct, 1 dozen boxes',
    image: 'alphonso', vendorId: 'v_devgad', unitLabel: 'dozen', tiers: [{ minQty: 12, unitPrice: 1150 }, { minQty: 24, unitPrice: 990 }],
    retailUnitPrice: 1450, minQty: 1, maxQty: 4, cutoffAt: iso(mangoCut), deliverAt: iso(istAt(mangoCut, 2, 11, 0)), pickupPoint: 'Clubhouse',
    description: 'Carbide-free, naturally ripened. Shipped by the FPO in one consignment for the whole society.',
  }, 'u_kiran', ago(20), soon, [
    [n('Rahul'), { qty: 2 }], [n('Divya'), { qty: 1 }], [n('Aditya'), { qty: 3 }], [n('Fatima'), { qty: 2 }],
    [n('Manoj'), { qty: 1 }], [n('Anjali'), { qty: 2 }], [n('Karthik'), { qty: 3 }], [n('Pooja'), { qty: 2 }],
  ]);

  const goatCut = nextDow(now, 6, 21, 0);
  bucket({
    id: 'b_goat', type: 'split', category: 'meat', title: 'Whole Goat, 7-share Split', subtitle: 'Al-Noor Meats, halal, Bakrid-style cut to order',
    image: 'goat', vendorId: 'v_alnoor', unitLabel: 'share', retailUnitPrice: 1000, unitPrice: 860,
    netWeight: '14 kg dressed', serves: '7 families', cutoffAt: iso(goatCut), deliverAt: iso(istAt(goatCut, 1, 7, 0)), pickupPoint: 'Gate 1',
    description: 'One young goat from the Pallavaram market, split into seven shares.',
    units: [
      { id: 'fl', label: 'Front leg (L)', grams: 2000, price: 1720 },
      { id: 'fr', label: 'Front leg (R)', grams: 2000, price: 1720 },
      { id: 'hl', label: 'Hind leg (L)', grams: 2200, price: 1890 },
      { id: 'hr', label: 'Hind leg (R)', grams: 2200, price: 1890 },
      { id: 'ribs', label: 'Ribs & chops', grams: 2000, price: 1720 },
      { id: 'shoulder', label: 'Shoulder & neck', grams: 2000, price: 1720 },
      { id: 'offal', label: 'Liver, kidney & keema', grams: 1600, price: 1150 },
    ],
    optionGroups: [{ key: 'cut', label: 'Cut', choices: ['Curry cut', 'Biryani cut', 'Keema'] }],
  }, n('Imran'), ago(28), soon, [
    [n('Imran'), { unitIds: ['fl'], ...cutOpt('Biryani cut') }], ['u_ravi', { unitIds: ['fr'], ...cutOpt('Curry cut') }],
    [n('Fatima'), { unitIds: ['hl'], ...cutOpt('Biryani cut') }], ['u_kiran', { unitIds: ['ribs'], ...cutOpt('Curry cut') }],
    [n('Farhan'), { unitIds: ['shoulder'], ...cutOpt('Biryani cut') }],
  ]);

  const meetAt = nextDow(now, 0, 6, 0, 8 * HOUR);
  const paaraiCut = new Date(meetAt.getTime() - 8 * HOUR);
  bucket({
    id: 'b_paarai', type: 'split', category: 'fish', title: 'Kasimedu Book & Meet: Whole Paarai', subtitle: 'Trevally, about 2.8 kg, split in two halves',
    image: 'paarai', vendorId: 'v_murugan', unitLabel: 'half', retailUnitPrice: 900, unitPrice: 520, settleMode: 'at_market',
    meet: { place: 'Gate 3', at: iso(meetAt), note: 'We ride to Kasimedu together. Pay Murugan at the stall.' },
    netWeight: '2.8 kg', serves: '2 families', cutoffAt: iso(paaraiCut), deliverAt: iso(meetAt), pickupPoint: 'Gate 3',
    units: [
      { id: 'head_half', label: 'Head half', grams: 1450, price: 760 },
      { id: 'tail_half', label: 'Tail half', grams: 1350, price: 700 },
    ],
    optionGroups: [{ key: 'cut', label: 'Cut', choices: ['Curry cut', 'Fry slices', 'Whole'] }],
  }, 'u_ravi', ago(6), soon, [['u_ravi', { unitIds: ['head_half'], payMode: 'at_market', ...cutOpt('Curry cut') }]]);

  store.data.seededAt = now.toISOString();
  return store.data;
}

/** Chat chatter posted around the cards so the Street isn't empty. */
const CHATTER_BEFORE = [
  ['u_ravi', 'Good morning Sea Breeze! Murugan anna says the seer at Kasimedu is excellent today.'],
  ['u_priya', 'Pest control bucket is up. Once we cross 50 flats it is only ₹340 per flat.'],
];
const CHATTER_AFTER = [
  [BOT_ID, 'Welcome to the Sea Breeze Street! Tap a bucket card to take your share. Money is only held, never taken, until the bucket fills.'],
  ['u_meera', 'Took a steak from the seer. Two cuts still open, who wants the tail?'],
];

/**
 * Pushes the seed into Nexconn: users + bot, Street groups, cards (sets cardMessageId), chatter.
 * Safe to run again: existing groups are joined, fresh cards are posted. Returns a summary.
 */
export async function seedNexconn(data, nx, { logger = console, oldData = null } = {}) {
  const summary = { users: 0, groups: [], cards: 0, texts: 0 };
  if (!nx.enabled) { logger.warn('[seed] Nexconn disabled, skipping chat setup'); return summary; }
  const store = new Store(null, data);

  // Start every seed with clean chats: dismiss the previous Street and bucket groups so no old cards, claims or
  // duplicate events from earlier runs show up (Nexconn keeps group history otherwise). They are recreated below.
  const oldGroups = new Set([
    ...Object.keys(oldData?.communities ?? {}).map((id) => streetGroupId(id)),
    ...Object.keys(data.communities ?? {}).map((id) => streetGroupId(id)),
    ...Object.values(oldData?.buckets ?? {}).filter((b) => b.orderId || b.status !== 'live').map((b) => bucketGroupId(b.id)),
    ...Object.keys(data.buckets ?? {}).map((id) => bucketGroupId(id)),
  ]);
  for (const channelId of oldGroups) {
    await nx.call('/v4/group-channel/dismiss', { channelId }).catch(() => {});
  }

  const users = [{ id: BOT_ID, name: BOT_NAME }, ...Object.values(data.users)];
  for (const u of users) {
    const t = await nx.ensureUser(u.id, u.name);
    if (t) { store.putNexconnToken(u.id, t); summary.users++; }
  }
  for (const c of store.communities()) {
    const ids = store.membersOf(c.id).map((m) => m.userId);
    const r = await nx.ensureStreet(c, ids);
    if (r) summary.groups.push(`${streetGroupId(c.id)} (${r.created ? 'created' : 'existed, joined'} · ${ids.length} members)`);
  }
  const svc = new JugaadService({ store, nx, logger });
  const sb = streetGroupId('c_seabreeze');
  const text = async (from, t, group = sb) => { if (await nx.sendText(group, t, from)) summary.texts++; };
  for (const [from, t] of CHATTER_BEFORE) await text(from, t);
  const live = store.buckets((b) => b.status === 'live').sort((a, b) => a.cutoffAt.localeCompare(b.cutoffAt)).reverse();
  for (const b of live) {
    const id = await nx.postBucketCard(svc.bucketView(b));
    if (id) { b.cardMessageId = id; summary.cards++; }
  }
  for (const [from, t] of CHATTER_AFTER) await text(from, t);
  await text(BOT_ID, 'Welcome to the Palm Grove Street! Start a bucket and your neighbours will see it here.', streetGroupId('c_palmgrove'));
  return summary;
}

/** Full reseed: build, keep sessions of users that still exist, push to Nexconn. */
export async function reseed({ store, nx, logger = console, now = new Date() }) {
  const old = store.data;
  const data = buildSeed(now);
  for (const [token, userId] of Object.entries(old.sessions ?? {})) if (data.users[userId]) data.sessions[token] = userId;
  const summary = await seedNexconn(data, nx, { logger, oldData: old });
  store.replace(data);
  return summary;
}
