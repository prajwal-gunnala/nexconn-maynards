// Human text helpers for chat events (IST, Indian rupee grouping).
const TZ = 'Asia/Kolkata';
const inr = new Intl.NumberFormat('en-IN');

export const rupees = (n) => `₹${inr.format(Math.round(n))}`;

function parts(d) {
  const f = new Intl.DateTimeFormat('en-IN', { timeZone: TZ, weekday: 'short', hour: 'numeric', minute: '2-digit', hour12: true });
  const o = Object.fromEntries(f.formatToParts(new Date(d)).map((p) => [p.type, p.value]));
  return { day: o.weekday, clock: `${o.hour}:${o.minute}`, ampm: (o.dayPeriod || '').toLowerCase() };
}

/** "Sat 8:00 pm" */
export function fmtTime(d) { const p = parts(d); return `${p.day} ${p.clock} ${p.ampm}`; }

/** "Sat 7:00–9:00 am" or "Sun 6:00 am at Gate 3" */
export function fmtWindow(bucket) {
  if (bucket.meet?.at) return `${fmtTime(bucket.meet.at)} at ${bucket.meet.place}`;
  if (!bucket.deliverAt) return '';
  const a = parts(bucket.deliverAt);
  const b = parts(new Date(new Date(bucket.deliverAt).getTime() + 2 * 3600_000));
  return a.ampm === b.ampm ? `${a.day} ${a.clock}–${b.clock} ${b.ampm}` : `${a.day} ${a.clock} ${a.ampm}–${b.clock} ${b.ampm}`;
}
