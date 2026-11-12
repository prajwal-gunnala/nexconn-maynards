// End-to-end bucket flows through the service, with Nexconn mocked.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { BULK, SPLIT, TRIP, setup } from './helpers.js';

test('bulk: tier unlock and final capture lower than the hold', async () => {
  const { svc, store, nx, create, take, u, clock } = setup();
  const b = create('meera', BULK);
  take('ravi', b.id, { qty: 40 });
  take('meera', b.id, { qty: 42 });
  const r = take('ananya', b.id, { qty: 10 });
  assert.equal(r.share.status, 'held');
  assert.equal(r.share.hold.amount, 960, '10 kg held at ₹96 (tier 1)');
  assert.equal(r.bucket.progress.filled, 92);
  assert.deepEqual(r.bucket.progress.nextTier, { minQty: 100, unitPrice: 88, remaining: 8 });
  const r2 = take('kiran', b.id, { qty: 8 });
  assert.equal(r2.bucket.progress.unitPrice, 88, '100 kg unlocks ₹88');
  assert.equal(r2.bucket.status, 'live', 'bulk keeps taking shares until the cutoff');
  await svc.flush();
  assert.ok(nx.named('postEvent').some((c) => /unlocked ₹88\/kg/.test(c.args[1].text)));

  clock.now = new Date(b.cutoffAt);
  const ran = svc.runCutoffs();
  assert.equal(ran[0].result.startsWith('order'), true);
  const ananya = store.sharesByUser('u_ananya')[0];
  assert.equal(ananya.status, 'captured');
  assert.equal(ananya.hold.capturedAmount, 880);
  assert.ok(ananya.hold.capturedAmount < ananya.hold.amount);
  const order = svc.getOrder(u('ananya'), store.bucket(b.id).orderId);
  assert.equal(order.total, 100 * 88);
  assert.equal(order.myLine.amount, 880);
});

test('split: double claim rejected, lock when the last part is paid', async () => {
  const { svc, store, nx, create, take, u } = setup();
  const b = create('ravi', SPLIT);
  const pending = svc.joinBucket(u('sunita'), b.id, { unitIds: ['head'] });
  assert.equal(pending.share.status, 'pending_payment');
  assert.throws(() => svc.joinBucket(u('meera'), b.id, { unitIds: ['head'] }), { code: 'UNIT_TAKEN', status: 409 });
  assert.throws(() => svc.joinBucket(u('meera'), b.id, { unitIds: ['s1', 's1'] }), { code: 'BAD_REQUEST' });
  assert.throws(() => svc.joinBucket(u('meera'), b.id, { unitIds: ['fin'] }), { code: 'UNKNOWN_UNIT' });
  svc.authorizeHold(u('sunita'), pending.share.hold.id, { vpa: 'sunita@okaxis', pin: '4321' });
  take('meera', b.id, { unitIds: ['s1'], options: { cut: 'Curry cut' } });
  const r = take('ananya', b.id, { unitIds: ['s2'] });
  assert.equal(r.share.hold.amount, 680);
  assert.equal(r.bucket.units.find((x) => x.id === 's2').owner.name, 'Ananya');
  assert.throws(() => svc.joinBucket(u('ananya'), b.id, { unitIds: ['tail'] }), { code: 'ALREADY_JOINED' });
  const last = take('kiran', b.id, { unitIds: ['tail'] });
  assert.equal(last.bucket.status, 'ordered', 'all parts held → locks immediately');
  await svc.flush();
  const order = store.order(last.bucket.orderId);
  assert.equal(order.lines.length, 4);
  assert.equal(order.total, 420 + 680 + 680 + 420);
  assert.ok(order.lines.every((l) => /^\d{4}$/.test(l.otp) && l.paymentStatus === 'captured'));
  assert.equal(new Set(order.lines.map((l) => l.otp)).size, 4);
  assert.deepEqual(order.lines.find((l) => l.name === 'Meera').options, { cut: 'Curry cut' });
  // Nexconn: card updates, bucket group with members + vendor, order card, one OTP DM per member
  assert.ok(nx.named('updateCard').length >= 4);
  const group = nx.named('createBucketGroup')[0].args;
  assert.deepEqual(group[1].sort(), ['u_ananya', 'u_kiran', 'u_meera', 'u_sunita', 'v_fish']);
  assert.equal(nx.named('postOrder').length, 1);
  assert.deepEqual(nx.named('sendOtp').map((c) => c.args[0]).sort(), ['u_ananya', 'u_kiran', 'u_meera', 'u_sunita']);
  assert.ok(nx.named('postEvent').some((c) => c.args[1].kind === 'locked'));
  // member sees only their own OTP; vendor sees none
  const mine = svc.getOrder(u('ananya'), order.id);
  assert.equal(mine.lines.filter((l) => l.otp).length, 1);
  assert.equal(mine.myLine.otp, store.sharesByUser('u_ananya')[0].otp);
  // handover with OTP
  const vendor = store.user('v_fish');
  assert.throws(() => svc.handover(u('meera'), order.id, { otp: mine.myLine.otp }), { code: 'FORBIDDEN' });
  assert.throws(() => svc.handover(vendor, order.id, { otp: '0000' }), { code: 'OTP_INVALID' });
  svc.handover(vendor, order.id, { otp: mine.myLine.otp });
  assert.throws(() => svc.handover(vendor, order.id, { otp: mine.myLine.otp }), { code: 'ALREADY_COLLECTED' });
  assert.equal(store.bucket(b.id).status, 'delivering');
  for (const l of order.lines.filter((x) => !x.collected)) svc.handover(vendor, order.id, { otp: l.otp });
  assert.equal(store.order(order.id).status, 'delivered');
  assert.equal(store.bucket(b.id).status, 'completed');
});

test('expire releases every hold', async () => {
  const { svc, store, nx, create, take, u } = setup();
  const b = create('ravi', SPLIT);
  take('sunita', b.id, { unitIds: ['head'] });
  take('meera', b.id, { unitIds: ['s1'] });
  const pending = svc.joinBucket(u('kiran'), b.id, { unitIds: ['tail'] });
  const { bucket, order } = svc.closeBucket(b.id);
  assert.equal(order, null);
  assert.equal(bucket.status, 'expired');
  const shares = store.sharesOf(b.id);
  assert.ok(shares.every((s) => s.status === 'released' && s.hold.status === 'released'));
  assert.throws(() => svc.authorizeHold(u('kiran'), pending.share.hold.id, { vpa: 'k@okaxis', pin: '1234' }), { code: 'INVALID_HOLD_STATE' });
  assert.throws(() => svc.closeBucket(b.id), { code: 'BUCKET_CLOSED' });
  await svc.flush();
  const ev = nx.named('postEvent').find((c) => c.args[1].kind === 'expired');
  assert.match(ev.args[1].text, /₹1,100 held has been released/);
  assert.equal(svc.wallet(u('meera')).releasedThisMonth, 680);
});

test('leaving frees the unit and releases the hold; unpaid claims time out', () => {
  const { svc, store, create, take, u, clock } = setup();
  const b = create('ravi', SPLIT);
  const r = take('meera', b.id, { unitIds: ['s1'] });
  const after = svc.leaveShare(u('meera'), r.share.id);
  assert.equal(after.bucket.units.find((x) => x.id === 's1').owner, null);
  assert.equal(store.share(r.share.id).hold.status, 'released');
  assert.throws(() => svc.leaveShare(u('ravi'), r.share.id), { code: 'FORBIDDEN' });
  const p = svc.joinBucket(u('kiran'), b.id, { unitIds: ['s1'] });
  clock.now = new Date(clock.now.getTime() + 16 * 60_000);
  svc.runCutoffs();
  assert.equal(store.share(p.share.id).status, 'released');
  assert.equal(svc.joinBucket(u('arjun'), b.id, { unitIds: ['s1'] }).share.status, 'pending_payment');
});

test('trip: transport split by weight, capacity enforced', () => {
  const { svc, store, create, take, u } = setup();
  const b = create('arjun', TRIP);
  const a = take('arjun', b.id, { items: [{ id: 'onion', qty: 20 }, { id: 'coconut', qty: 20 }] }); // 30 kg
  assert.equal(a.share.qty, 30);
  // goods 20×28 + 20×22 = 1000; transport 1000 × 30 / max(30, 40) = 750
  assert.equal(a.share.hold.amount, 1750);
  take('kiran', b.id, { items: [{ id: 'onion', qty: 20 }] });
  take('meera', b.id, { items: [{ id: 'onion', qty: 10 }] });
  assert.throws(() => svc.joinBucket(u('ravi'), b.id, { items: [{ id: 'onion', qty: 41 }] }), { code: 'CAPACITY_FULL' });
  assert.throws(() => svc.joinBucket(u('ravi'), b.id, { items: [{ id: 'mango', qty: 1 }] }), { code: 'UNKNOWN_ITEM' });
  const view = svc.getBucket(b.id, 'u_arjun');
  assert.equal(view.progress.filled, 60);
  assert.deepEqual(view.items.map((i) => [i.id, i.qty, i.members]), [['onion', 50, 3], ['coconut', 20, 1]]);
  const { order } = svc.closeBucket(b.id);
  const t = Object.fromEntries(order.lines.map((l) => [l.name, l.transport]));
  assert.deepEqual(t, { Arjun: 500, Kiran: 333, Meera: 167 }, '₹1,000 split 30:20:10 kg');
  assert.equal(order.lines.reduce((n, l) => n + l.transport, 0), 1000);
  assert.equal(order.lines.find((l) => l.name === 'Arjun').amount, 1500);
  assert.equal(order.lines.find((l) => l.name === 'Arjun').qtyLabel, 'Onion 20 kg · Coconut 20 pc');
  assert.ok(store.sharesOf(b.id).every((s) => s.hold.capturedAmount <= s.hold.amount));
});

test('at_market: book without a hold, pay at pickup', async () => {
  const { svc, store, create, u, nx } = setup();
  const b = create('ravi', {
    type: 'split', category: 'fish', title: 'Paarai halves', settleMode: 'at_market', unitLabel: 'half',
    meet: { place: 'Gate 3', at: '2026-11-15T00:30:00.000Z' },
    units: [{ id: 'h1', label: 'Head half', price: 760 }, { id: 'h2', label: 'Tail half', price: 700 }],
  });
  assert.throws(() => svc.joinBucket(u('ananya'), b.id, { unitIds: ['h1'], payMode: 'hold' }), { code: 'PAY_MODE_NOT_ALLOWED' });
  const r1 = svc.joinBucket(u('ravi'), b.id, { unitIds: ['h1'], payMode: 'at_market' });
  assert.equal(r1.share.status, 'booked');
  assert.equal(r1.share.hold, null);
  const r2 = svc.joinBucket(u('ananya'), b.id, { unitIds: ['h2'] });
  assert.equal(r2.bucket.status, 'market_day', 'both halves booked → order, status market_day');
  const order = store.order(r2.bucket.orderId);
  assert.ok(order.lines.every((l) => l.payMode === 'at_market' && l.paymentStatus === 'due'));
  assert.deepEqual([order.total, order.heldTotal, order.atPickupTotal], [1460, 0, 1460]);
  assert.equal(order.window, 'Sun 6:00 am at Gate 3');
  const c = svc.checkin(u('ananya'), r2.share.id);
  assert.equal(c.share.status, 'checked_in');
  svc.handover(store.user('v_fish'), order.id, { otp: c.share.otp });
  assert.equal(store.order(order.id).lines.find((l) => l.userId === 'u_ananya').paymentStatus, 'paid');
  const w = svc.wallet(u('ananya'));
  assert.equal(w.heldNow, 0);
  assert.equal(w.paidThisMonth, 700);
  await svc.flush();
  assert.ok(nx.named('postEvent').some((x) => x.args[1].kind === 'checkin' && x.args[0] === `bucket_${b.id}`));
});

test('wallet through a real flow', () => {
  const { svc, create, take, u } = setup();
  const b = create('meera', BULK);
  take('ravi', b.id, { qty: 50 });
  take('ananya', b.id, { qty: 50 }); // 50 × 96 held, tier 100 reached on her own claim → 88
  let w = svc.wallet(u('ravi'));
  assert.equal(w.heldNow, 4800);
  svc.closeBucket(b.id);
  w = svc.wallet(u('ravi'));
  assert.deepEqual([w.heldNow, w.paidThisMonth, w.savedThisMonth], [0, 4400, 50 * 135 - 4400]);
  assert.equal(svc.wallet(u('ananya')).paidThisMonth, 4400);
});

test('admin nudges and vendor dashboard', async () => {
  const { svc, create, take, u, store, nx } = setup();
  const b = create('ravi', SPLIT);
  take('meera', b.id, { unitIds: ['s1'] });
  const admin = svc.adminCommunity(u('priya'), 'c_test');
  assert.match(admin.nudges[0].text, /Head, Steak 2 and Tail are still open\. 3 cuts left/);
  assert.throws(() => svc.adminCommunity(u('meera'), 'c_test'), { code: 'FORBIDDEN' });
  svc.nudge(u('priya'), { bucketId: b.id });
  await svc.flush();
  assert.equal(nx.named('postEvent').at(-1).args[1].kind, 'nudge');
  const dash = svc.vendorDashboard(store.user('v_fish'));
  assert.equal(dash.heldDemand, 680);
  assert.equal(dash.buckets.length, 1);
  assert.throws(() => svc.vendorDashboard(u('meera')), { code: 'NOT_VENDOR' });
});

test('Nexconn failure never breaks the API', async () => {
  const { svc, store, nx, create, take } = setup();
  for (const k of ['postBucketCard', 'updateCard', 'postEvent']) nx[k] = async () => { throw new Error('boom'); };
  const b = create('ravi', SPLIT);
  const r = take('meera', b.id, { unitIds: ['s1'] });
  assert.equal(r.share.status, 'held');
  await svc.flush();
  assert.equal(store.bucket(b.id).cardMessageId, null);
});
