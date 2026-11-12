// Pure pricing for all bucket types. All money is integer rupees.
//   split   – fixed price per unit (cut / share); qty = number of units
//   bulk    – volume tiers on a shared quantity (kg, dozen)
//   service – volume tiers per flat
//   trip    – shopping list at item prices + transport fee shared by weight

export const ACTIVE = new Set(['pending_payment', 'held', 'booked', 'captured', 'checked_in', 'collected']);
export const COMMITTED = new Set(['held', 'booked', 'captured', 'checked_in', 'collected']);
export const isActive = (s) => ACTIVE.has(s.status);
export const isCommitted = (s) => COMMITTED.has(s.status);

const byMin = (tiers = []) => [...tiers].sort((a, b) => a.minQty - b.minQty);

export function tierFor(tiers, qty) {
  let hit = null;
  for (const t of byMin(tiers)) if (qty >= t.minQty) hit = t;
  return hit;
}

export function nextTier(tiers, qty) {
  const t = byMin(tiers).find((x) => x.minQty > qty);
  return t ? { minQty: t.minQty, unitPrice: t.unitPrice, remaining: t.minQty - qty } : null;
}

/** Unit price for bulk/service at a total quantity. Below the first tier, the first tier's price (or bucket.unitPrice). */
export function unitPriceAt(bucket, totalQty) {
  const t = tierFor(bucket.tiers, totalQty);
  if (t) return t.unitPrice;
  return bucket.unitPrice ?? byMin(bucket.tiers)[0]?.unitPrice ?? 0;
}

/** Minimum committed quantity for the bucket to go ahead at cutoff. */
export function goAt(bucket) {
  if (bucket.type === 'split') return bucket.units.length;
  if (bucket.type === 'trip') return bucket.minLoadKg ?? 1;
  return byMin(bucket.tiers)[0]?.minQty ?? 1;
}

export function target(bucket) {
  if (bucket.type === 'split') return bucket.units.length;
  if (bucket.type === 'trip') return bucket.capacity;
  return bucket.lotQty ?? byMin(bucket.tiers).at(-1)?.minQty ?? 1;
}

export function itemsKg(bucket, items = []) {
  let kg = 0;
  for (const it of items) {
    const def = bucket.items.find((i) => i.id === it.id);
    kg += it.qty * (def?.kgPerUnit ?? 1);
  }
  return Math.round(kg * 100) / 100;
}

export function itemsGoods(bucket, items = []) {
  let sum = 0;
  for (const it of items) sum += it.qty * (bucket.items.find((i) => i.id === it.id)?.price ?? 0);
  return Math.round(sum);
}

/** Quantity a share contributes to `filled` (units, kg, dozens, flats). */
export function shareQty(bucket, share) {
  if (bucket.type === 'split') return share.unitIds?.length ?? 0;
  if (bucket.type === 'trip') return itemsKg(bucket, share.items);
  return share.qty ?? 0;
}

export const sumQty = (bucket, shares) => shares.reduce((n, s) => n + shareQty(bucket, s), 0);

/** Split `total` across `weights` in integers that add up exactly (largest remainder). */
export function splitByWeight(total, weights) {
  const W = weights.reduce((a, b) => a + b, 0);
  if (!W) return weights.map(() => 0);
  const raw = weights.map((w) => (total * w) / W);
  const out = raw.map(Math.floor);
  let left = total - out.reduce((a, b) => a + b, 0);
  const order = raw.map((r, i) => [r - Math.floor(r), i]).sort((a, b) => b[0] - a[0]);
  for (let k = 0; left > 0; k = (k + 1) % order.length, left--) out[order[k][1]]++;
  return out;
}

/**
 * Estimated amount for a new claim, given the shares already committed. This is what gets held.
 * bulk/service price at the tier reached including this claim; trip transport by weight against
 * max(total kg incl. this claim, minimum load).
 */
export function quoteClaim(bucket, claim, committedShares) {
  const filled = sumQty(bucket, committedShares);
  switch (bucket.type) {
    case 'split':
      return claim.unitIds.reduce((s, id) => s + (bucket.units.find((u) => u.id === id)?.price ?? 0), 0);
    case 'bulk':
    case 'service':
      return claim.qty * unitPriceAt(bucket, filled + claim.qty);
    case 'trip': {
      const kg = itemsKg(bucket, claim.items);
      const fee = bucket.transportFee ?? 0;
      const transport = Math.round((fee * kg) / Math.max(filled + kg, bucket.minLoadKg ?? 1));
      return itemsGoods(bucket, claim.items) + transport;
    }
    default:
      throw new Error(`unknown bucket type ${bucket.type}`);
  }
}

/**
 * Final amounts at order time for the committed shares (Map shareId → {amount, transport?}).
 * Hold-mode amounts never exceed what was held ("you never pay more than you reserved").
 */
export function finalAmounts(bucket, committedShares) {
  const out = new Map();
  if (bucket.type === 'trip') {
    const kgs = committedShares.map((s) => itemsKg(bucket, s.items));
    const transport = splitByWeight(bucket.transportFee ?? 0, kgs.map((k) => Math.round(k * 100)));
    committedShares.forEach((s, i) => out.set(s.id, { amount: itemsGoods(bucket, s.items) + transport[i], transport: transport[i] }));
  } else if (bucket.type === 'split') {
    for (const s of committedShares) out.set(s.id, { amount: quoteClaim(bucket, s, []) });
  } else {
    const price = unitPriceAt(bucket, sumQty(bucket, committedShares));
    for (const s of committedShares) out.set(s.id, { amount: s.qty * price, unitPrice: price });
  }
  for (const s of committedShares) {
    const r = out.get(s.id);
    if (s.payMode === 'hold' && s.hold) r.amount = Math.min(r.amount, s.hold.amount);
  }
  return out;
}

/** What the share would cost at retail (local shop / online), for savings. */
export function retailAmount(bucket, share) {
  if (bucket.type === 'split') {
    return share.unitIds.reduce((sum, id) => {
      const u = bucket.units.find((x) => x.id === id);
      if (!u) return sum;
      if (u.retailPrice) return sum + u.retailPrice;
      return sum + Math.round(((u.grams ?? 0) / 1000) * (bucket.retailUnitPrice ?? 0));
    }, 0);
  }
  if (bucket.type === 'trip') {
    return Math.round(share.items.reduce((sum, it) => {
      const def = bucket.items.find((i) => i.id === it.id);
      return sum + it.qty * (def?.retailPrice ?? def?.price ?? 0);
    }, 0));
  }
  return (share.qty ?? 0) * (bucket.retailUnitPrice ?? 0);
}

export const savings = (bucket, share, amount) => Math.max(0, retailAmount(bucket, share) - amount);

/** Live progress block (also the `p` card metadata). `shares` = all shares of the bucket. */
export function progress(bucket, shares) {
  const committed = shares.filter(isCommitted);
  const filled = sumQty(bucket, committed);
  const tgt = target(bucket);
  const held = shares.reduce((s, x) => s + (x.hold?.status === 'held' ? x.hold.amount : 0), 0);
  const p = {
    filled: Math.round(filled * 100) / 100,
    target: tgt,
    members: committed.length,
    held,
    unitPrice: bucket.type === 'bulk' || bucket.type === 'service' ? unitPriceAt(bucket, filled)
      : bucket.type === 'split' ? bucket.unitPrice ?? null : null,
    nextTier: bucket.type === 'bulk' || bucket.type === 'service' ? nextTier(bucket.tiers, filled) : null,
    percent: tgt ? Math.min(100, Math.round((filled / tgt) * 100)) : 0,
    goAt: goAt(bucket),
  };
  if (bucket.type === 'trip') {
    p.transportPerKg = Math.round(((bucket.transportFee ?? 0) / Math.max(filled, bucket.minLoadKg ?? 1)) * 100) / 100;
  }
  return p;
}

const NO_PLURAL = new Set(['kg', 'g', 'l', 'L', 'dozen', 'ml', 'pc', 'pcs']);
export const plural = (n, label) => `${n} ${n === 1 || NO_PLURAL.has(label) ? label : `${label}s`}`;

export function qtyLabel(bucket, share) {
  if (bucket.type === 'split') {
    return share.unitIds.map((id) => bucket.units.find((u) => u.id === id)?.label ?? id).join(', ');
  }
  if (bucket.type === 'trip') {
    return share.items.map((it) => {
      const def = bucket.items.find((i) => i.id === it.id);
      return `${def?.name ?? it.id} ${plural(it.qty, def?.unit ?? 'kg')}`;
    }).join(' · ');
  }
  return plural(share.qty, bucket.unitLabel);
}
