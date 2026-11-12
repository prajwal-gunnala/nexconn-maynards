// Wallet aggregation for one member. Pure. Months are IST calendar months.
import { savings } from './pricing.js';

const IST_MS = 330 * 60_000;
export const istMonthKey = (d) => { const x = new Date(new Date(d).getTime() + IST_MS); return `${x.getUTCFullYear()}-${x.getUTCMonth()}`; };

/**
 * @param shares   the member's shares (all statuses)
 * @param buckets  Map/obj bucketId → bucket
 * @returns {heldNow, paidThisMonth, releasedThisMonth, savedTotal, savedThisMonth, entries}
 */
export function walletFor(shares, buckets, now = new Date()) {
  const month = istMonthKey(now);
  const get = (id) => (buckets instanceof Map ? buckets.get(id) : buckets[id]);
  const entries = [];
  for (const s of shares) {
    const b = get(s.bucketId);
    if (!b) continue;
    const base = { shareId: s.id, bucketId: b.id, title: b.title, image: b.image, orderId: s.orderId ?? null };
    const h = s.hold;
    if (s.payMode === 'hold' && h) {
      if (h.status === 'held') entries.push({ ...base, id: `${h.id}_held`, kind: 'held', amount: h.amount, savings: 0, at: h.heldAt });
      else if (h.status === 'captured') {
        entries.push({ ...base, id: `${h.id}_paid`, kind: 'paid', amount: h.capturedAmount, heldAmount: h.amount,
          savings: savings(b, s, h.capturedAmount), at: h.capturedAt });
      } else if (h.status === 'released' && h.heldAt) {
        entries.push({ ...base, id: `${h.id}_released`, kind: 'released', amount: h.amount, savings: 0, at: h.releasedAt });
      }
    } else if (s.payMode === 'at_market' && s.finalAmount != null && s.status !== 'released' && s.status !== 'left') {
      entries.push({ ...base, id: `${s.id}_market`, kind: s.status === 'collected' ? 'paid' : 'at_market',
        amount: s.finalAmount, savings: savings(b, s, s.finalAmount), at: s.collectedAt ?? s.orderedAt ?? s.createdAt });
    }
  }
  entries.sort((a, b) => String(b.at).localeCompare(String(a.at)));
  const inMonth = (e) => e.at && istMonthKey(e.at) === month;
  const sum = (list, f = (e) => e.amount) => list.reduce((n, e) => n + f(e), 0);
  const paid = entries.filter((e) => e.kind === 'paid');
  const saving = entries.filter((e) => e.kind === 'paid' || e.kind === 'at_market');
  return {
    heldNow: sum(entries.filter((e) => e.kind === 'held')),
    paidThisMonth: sum(paid.filter(inMonth)),
    releasedThisMonth: sum(entries.filter((e) => e.kind === 'released' && inMonth(e))),
    savedTotal: sum(saving, (e) => e.savings),
    savedThisMonth: sum(saving.filter(inMonth), (e) => e.savings),
    entries,
  };
}
