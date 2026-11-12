// Validates a new claim on a bucket and normalises the request. Pure.
import { fail } from './errors.js';
import { isActive, itemsKg, sumQty } from './pricing.js';

/**
 * @param bucket  stored bucket
 * @param shares  all shares of this bucket
 * @param userId  claimer
 * @param req     {unitIds?, qty?, items?, options?, payMode?}
 * @param now     Date
 * @returns {payMode, unitIds, qty, items, options}
 */
export function validateClaim(bucket, shares, userId, req = {}, now = new Date()) {
  if (bucket.status !== 'live') fail('BUCKET_CLOSED', 'This bucket is no longer taking shares.', 409);
  if (new Date(bucket.cutoffAt) <= now) fail('BUCKET_CLOSED', 'The cutoff for this bucket has passed.', 409);
  const active = shares.filter(isActive);
  if (active.some((s) => s.user.id === userId)) {
    fail('ALREADY_JOINED', 'You already have a share in this bucket. Leave it first to change it.', 409);
  }
  const payMode = req.payMode ?? bucket.settleMode;
  if (payMode !== 'hold' && payMode !== 'at_market') fail('BAD_REQUEST', 'payMode must be "hold" or "at_market".');
  if (payMode !== bucket.settleMode) {
    fail('PAY_MODE_NOT_ALLOWED', bucket.settleMode === 'at_market'
      ? 'This bucket is book-and-meet: you pay at the market.' : 'This bucket needs a UPI hold.');
  }
  const options = req.options && typeof req.options === 'object' ? req.options : null;
  const out = { payMode, unitIds: null, qty: null, items: null, options };

  if (bucket.type === 'split') {
    const ids = req.unitIds;
    if (!Array.isArray(ids) || ids.length === 0) fail('BAD_REQUEST', 'Pick at least one part (unitIds).');
    if (new Set(ids).size !== ids.length) fail('BAD_REQUEST', 'The same part was picked twice.');
    if (bucket.maxUnitsPerMember && ids.length > bucket.maxUnitsPerMember) {
      fail('QTY_TOO_HIGH', `You can take at most ${bucket.maxUnitsPerMember} parts.`);
    }
    const taken = new Set(active.flatMap((s) => s.unitIds ?? []));
    for (const id of ids) {
      const unit = bucket.units.find((u) => u.id === id);
      if (!unit) fail('UNKNOWN_UNIT', `There is no part "${id}" in this bucket.`);
      if (taken.has(id)) fail('UNIT_TAKEN', `${unit.label} was just taken by a neighbour.`, 409);
    }
    out.unitIds = [...ids];
    out.qty = ids.length;
  } else if (bucket.type === 'bulk' || bucket.type === 'service') {
    const qty = Number(req.qty);
    if (!Number.isInteger(qty) || qty <= 0) fail('BAD_REQUEST', 'qty must be a whole number above 0.');
    const min = bucket.minQty ?? 1;
    const max = bucket.maxQty ?? Infinity;
    if (qty < min) fail('QTY_TOO_LOW', `The minimum is ${min} ${bucket.unitLabel}.`);
    if (qty > max) fail('QTY_TOO_HIGH', `The maximum per member is ${max} ${bucket.unitLabel}.`);
    if (bucket.lotQty) {
      const left = bucket.lotQty - sumQty(bucket, active);
      if (qty > left) fail('SOLD_OUT', left > 0 ? `Only ${left} ${bucket.unitLabel} left.` : 'This lot is fully claimed.', 409);
    }
    out.qty = qty;
  } else if (bucket.type === 'trip') {
    const items = req.items;
    if (!Array.isArray(items) || items.length === 0) fail('BAD_REQUEST', 'Add at least one item.');
    const seen = new Set();
    for (const it of items) {
      const def = bucket.items.find((i) => i.id === it?.id);
      if (!def) fail('UNKNOWN_ITEM', `"${it?.id}" is not on this trip's list.`);
      if (seen.has(it.id)) fail('BAD_REQUEST', `${def.name} is listed twice.`);
      seen.add(it.id);
      if (!(Number(it.qty) > 0)) fail('BAD_REQUEST', `Quantity for ${def.name} must be above 0.`);
      if (def.maxQty && it.qty > def.maxQty) fail('QTY_TOO_HIGH', `At most ${def.maxQty} ${def.unit} of ${def.name}.`);
    }
    out.items = items.map((it) => ({ id: it.id, qty: Number(it.qty) }));
    const kg = itemsKg(bucket, out.items);
    const used = sumQty(bucket, active);
    if (used + kg > bucket.capacity) {
      fail('CAPACITY_FULL', `The vehicle has room for ${Math.max(0, bucket.capacity - used)} kg more.`, 409);
    }
    out.qty = kg;
  } else {
    fail('BAD_REQUEST', `Unknown bucket type ${bucket.type}.`);
  }
  return out;
}
