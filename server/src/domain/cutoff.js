// Cutoff and lock decisions + order building. Pure (rng injectable).
import { finalAmounts, goAt, isActive, isCommitted, qtyLabel, savings, sumQty } from './pricing.js';

/** True when the bucket should lock right now, before its cutoff. */
export function isFilled(bucket, shares) {
  const filled = sumQty(bucket, shares.filter(isCommitted));
  if (bucket.type === 'split') return filled >= bucket.units.length;
  if (bucket.type === 'trip') return filled >= bucket.capacity;
  return bucket.lotQty ? filled >= bucket.lotQty : false;
}

/** At the cutoff: 'order' when filled (split) or the first tier / minimum load is reached, else 'expire'. */
export function cutoffDecision(bucket, shares) {
  const committed = shares.filter(isCommitted);
  if (!committed.length) return 'expire';
  return sumQty(bucket, committed) >= goAt(bucket) ? 'order' : 'expire';
}

export function makeOtp(rng = Math.random, used = new Set()) {
  for (let i = 0; i < 1000; i++) {
    const otp = String(Math.floor(rng() * 9000) + 1000);
    if (!used.has(otp)) { used.add(otp); return otp; }
  }
  throw new Error('could not make a unique OTP');
}

/**
 * Builds the order for a bucket that goes ahead. One line per committed member.
 * Pending (unpaid) shares are returned in `release` and are not part of the order.
 */
export function buildOrder(bucket, shares, { orderId, now = new Date(), rng = Math.random, window = '' }) {
  const committed = shares.filter(isCommitted);
  const finals = finalAmounts(bucket, committed);
  const used = new Set();
  const lines = committed.map((s) => {
    const f = finals.get(s.id);
    return {
      shareId: s.id, userId: s.user.id, name: s.user.name, unit: s.user.unit,
      qty: s.qty, qtyLabel: qtyLabel(bucket, s), amount: f.amount,
      ...(f.transport !== undefined ? { transport: f.transport } : {}),
      payMode: s.payMode, paymentStatus: s.payMode === 'hold' ? 'captured' : 'due',
      otp: makeOtp(rng, used), collected: false, options: s.options ?? null,
      savings: savings(bucket, s, f.amount),
    };
  });
  const sum = (pred) => lines.filter(pred).reduce((n, l) => n + l.amount, 0);
  const order = {
    id: orderId, bucketId: bucket.id, communityId: bucket.communityId, vendorId: bucket.vendor?.id ?? null,
    title: bucket.title, image: bucket.image,
    total: sum(() => true), heldTotal: sum((l) => l.payMode === 'hold'), atPickupTotal: sum((l) => l.payMode === 'at_market'),
    status: 'created', createdAt: now.toISOString(), pickupPoint: bucket.meet?.place ?? bucket.pickupPoint ?? '',
    window, lines,
  };
  const release = shares.filter((s) => isActive(s) && !isCommitted(s)).map((s) => s.id);
  return { order, release };
}
