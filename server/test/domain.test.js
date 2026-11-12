// Pure domain modules: pricing, claims, holds, cutoff, wallet.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import * as P from '../src/domain/pricing.js';
import { validateClaim } from '../src/domain/claims.js';
import { authorizeHold, captureHold, createHold, releaseHold } from '../src/domain/holds.js';
import { buildOrder, cutoffDecision, isFilled } from '../src/domain/cutoff.js';
import { walletFor } from '../src/domain/wallet.js';

const bulk = { id: 'b', type: 'bulk', status: 'live', settleMode: 'hold', unitLabel: 'kg', cutoffAt: '2099-01-01T00:00:00Z',
  retailUnitPrice: 135, minQty: 5, maxQty: 50, tiers: [{ minQty: 100, unitPrice: 88 }, { minQty: 25, unitPrice: 96 }] };
const sh = (id, qty, extra = {}) => ({ id, user: { id: `u_${id}`, name: id, unit: 'A-1' }, qty, status: 'held', payMode: 'hold', ...extra });

test('tier selection and next tier', () => {
  assert.equal(P.tierFor(bulk.tiers, 10), null);
  assert.equal(P.unitPriceAt(bulk, 10), 96, 'below the first tier the first tier price is quoted');
  assert.equal(P.unitPriceAt(bulk, 82), 96);
  assert.equal(P.unitPriceAt(bulk, 100), 88);
  assert.deepEqual(P.nextTier(bulk.tiers, 82), { minQty: 100, unitPrice: 88, remaining: 18 });
  assert.equal(P.nextTier(bulk.tiers, 120), null);
  const p = P.progress(bulk, [sh('a', 50, { hold: { status: 'held', amount: 4800 } }), sh('b', 32, { status: 'pending_payment' })]);
  assert.deepEqual([p.filled, p.target, p.members, p.held, p.unitPrice, p.percent], [50, 100, 1, 4800, 96, 50]);
});

test('final amounts never exceed the hold', () => {
  const shares = [sh('a', 60, { hold: { amount: 5760 } }), sh('b', 40, { hold: { amount: 3520 } })];
  const f = P.finalAmounts(bulk, shares);
  assert.equal(f.get('a').amount, 5280); // 60 × 88
  assert.equal(f.get('b').amount, 3520);
  const capped = P.finalAmounts(bulk, [sh('c', 30, { hold: { amount: 2000 } })]);
  assert.equal(capped.get('c').amount, 2000, '30 × 96 = 2880 is capped at the 2000 held');
});

test('splitByWeight adds up exactly', () => {
  const parts = P.splitByWeight(1000, [1, 1, 1]);
  assert.equal(parts.reduce((a, b) => a + b, 0), 1000);
  assert.deepEqual(parts.sort(), [333, 333, 334]);
  assert.deepEqual(P.splitByWeight(1800, [20, 30, 10]), [600, 900, 300]);
});

test('claims: quantity limits and lot size', () => {
  assert.throws(() => validateClaim(bulk, [], 'u', { qty: 2 }), { code: 'QTY_TOO_LOW' });
  assert.throws(() => validateClaim(bulk, [], 'u', { qty: 60 }), { code: 'QTY_TOO_HIGH' });
  assert.throws(() => validateClaim(bulk, [], 'u', { qty: 7.5 }), { code: 'BAD_REQUEST' });
  assert.throws(() => validateClaim({ ...bulk, lotQty: 30 }, [sh('a', 28)], 'u', { qty: 5 }), { code: 'SOLD_OUT' });
  assert.throws(() => validateClaim(bulk, [sh('a', 10)], 'u_a', { qty: 5 }), { code: 'ALREADY_JOINED' });
  assert.throws(() => validateClaim(bulk, [], 'u', { qty: 5, payMode: 'at_market' }), { code: 'PAY_MODE_NOT_ALLOWED' });
  assert.throws(() => validateClaim({ ...bulk, cutoffAt: '2000-01-01T00:00:00Z' }, [], 'u', { qty: 5 }), { code: 'BUCKET_CLOSED' });
  assert.equal(validateClaim(bulk, [], 'u', { qty: 10 }).payMode, 'hold');
});

test('hold state machine', () => {
  const h = createHold('h1', 700);
  assert.equal(h.status, 'created');
  assert.throws(() => authorizeHold(h, { vpa: 'a@okaxis', pin: '0000' }), { code: 'PIN_INCORRECT' });
  assert.throws(() => authorizeHold(h, { vpa: 'a@okaxis', pin: '12' }), { code: 'INVALID_PIN' });
  assert.throws(() => authorizeHold(h, { vpa: 'nope', pin: '1234' }), { code: 'INVALID_VPA' });
  assert.throws(() => captureHold(h, 700), { code: 'INVALID_HOLD_STATE' }, 'cannot capture an unauthorised hold');
  const held = authorizeHold(h, { vpa: 'ananya@okaxis', pin: '123456' });
  assert.equal(held.status, 'held');
  assert.throws(() => captureHold(held, 701), /exceeds/);
  const cap = captureHold(held, 640);
  assert.deepEqual([cap.status, cap.capturedAmount], ['captured', 640]);
  assert.throws(() => releaseHold(cap), { code: 'INVALID_HOLD_STATE' });
  assert.equal(releaseHold(h).status, 'released', 'created → released is allowed');
});

test('cutoff decisions and order building', () => {
  assert.equal(cutoffDecision(bulk, [sh('a', 20)]), 'expire');
  assert.equal(cutoffDecision(bulk, [sh('a', 20), sh('b', 5)]), 'order');
  assert.equal(isFilled(bulk, [sh('a', 200)]), false, 'bulk without a lot size waits for the cutoff');
  const shares = [sh('a', 20, { hold: { status: 'held', amount: 1920 } }), sh('b', 10, { status: 'booked', payMode: 'at_market' }),
    sh('c', 5, { status: 'pending_payment', hold: { status: 'created', amount: 480 } })];
  const { order, release } = buildOrder({ ...bulk, settleMode: 'hold' }, shares, { orderId: 'JS-1', rng: ((x) => () => (x += 0.37) % 1)(0) });
  assert.equal(order.lines.length, 2);
  assert.deepEqual(release, ['c']);
  assert.deepEqual(order.lines.map((l) => [l.amount, l.payMode, l.paymentStatus, l.qtyLabel]),
    [[1920, 'hold', 'captured', '20 kg'], [960, 'at_market', 'due', '10 kg']]);
  assert.deepEqual([order.total, order.heldTotal, order.atPickupTotal], [2880, 1920, 960]);
  assert.match(order.lines[0].otp, /^\d{4}$/);
  assert.notEqual(order.lines[0].otp, order.lines[1].otp, 'OTPs are unique within an order');
});

test('wallet aggregation', () => {
  const now = new Date('2026-11-13T04:00:00Z');
  const buckets = { b: { ...bulk, title: 'Basmati' } };
  const shares = [
    sh('held', 10, { bucketId: 'b', hold: { id: 'h1', status: 'held', amount: 960, heldAt: '2026-11-12T10:00:00Z' } }),
    sh('paid', 10, { bucketId: 'b', status: 'captured', hold: { id: 'h2', status: 'captured', amount: 960, capturedAmount: 880, capturedAt: '2026-11-05T10:00:00Z' } }),
    sh('old', 5, { bucketId: 'b', status: 'captured', hold: { id: 'h3', status: 'captured', amount: 480, capturedAmount: 440, capturedAt: '2026-10-20T10:00:00Z' } }),
    sh('rel', 5, { bucketId: 'b', status: 'released', hold: { id: 'h4', status: 'released', amount: 480, heldAt: '2026-11-01T10:00:00Z', releasedAt: '2026-11-02T10:00:00Z' } }),
    sh('never', 5, { bucketId: 'b', status: 'released', hold: { id: 'h5', status: 'released', amount: 480, releasedAt: '2026-11-02T10:00:00Z' } }),
    sh('mkt', 4, { bucketId: 'b', status: 'collected', payMode: 'at_market', finalAmount: 384, collectedAt: '2026-11-10T01:00:00Z' }),
  ];
  const w = walletFor(shares, buckets, now);
  assert.equal(w.heldNow, 960);
  assert.equal(w.paidThisMonth, 880 + 384, 'captured holds + at-market paid this month');
  assert.equal(w.releasedThisMonth, 480, 'a hold never authorised is not counted as released money');
  // savings: 10 kg × 135 − 880 = 470; 5 × 135 − 440 = 235; 4 × 135 − 384 = 156
  assert.equal(w.savedTotal, 470 + 235 + 156);
  assert.equal(w.savedThisMonth, 470 + 156);
  assert.deepEqual(w.entries.map((e) => e.kind), ['held', 'paid', 'paid', 'released', 'paid']);
});
