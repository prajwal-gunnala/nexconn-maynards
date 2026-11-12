// Sandboxed UPI Reserve hold: created → held → captured | released (created → released too). Pure.
import { fail } from './errors.js';

const NEXT = { created: ['held', 'released'], held: ['captured', 'released'], captured: [], released: [] };

export function createHold(id, amount, now = new Date()) {
  if (!Number.isInteger(amount) || amount < 0) throw new Error('hold amount must be integer rupees');
  return { id, amount, status: 'created', vpa: null, createdAt: now.toISOString() };
}

function move(hold, to) {
  if (!NEXT[hold.status]?.includes(to)) {
    fail('INVALID_HOLD_STATE', `This payment is already ${hold.status}.`, 409);
  }
}

export function authorizeHold(hold, { vpa, pin } = {}, now = new Date()) {
  move(hold, 'held');
  const p = String(pin ?? '');
  if (!/^\d{4,6}$/.test(p)) fail('INVALID_PIN', 'Enter your 4–6 digit UPI PIN.');
  if (p === '0000') fail('PIN_INCORRECT', 'Incorrect UPI PIN. No money was blocked.');
  const v = String(vpa ?? '').trim();
  if (!/^[\w.-]+@[a-zA-Z][\w]{1,}$/.test(v)) fail('INVALID_VPA', 'Enter a UPI ID like name@okaxis.');
  return { ...hold, status: 'held', vpa: v, heldAt: now.toISOString() };
}

export function captureHold(hold, amount, now = new Date()) {
  move(hold, 'captured');
  if (amount > hold.amount) throw new Error(`capture ${amount} exceeds hold ${hold.amount}`);
  return { ...hold, status: 'captured', capturedAmount: amount, capturedAt: now.toISOString() };
}

export function releaseHold(hold, now = new Date()) {
  move(hold, 'released');
  return { ...hold, status: 'released', releasedAt: now.toISOString() };
}
