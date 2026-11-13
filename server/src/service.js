// Application service: glues the store, the pure domain modules and Nexconn side effects.
// Nexconn calls run on a background queue so the API stays fast and keeps working when Nexconn is down.
import crypto from 'node:crypto';
import { fail } from './domain/errors.js';
import * as P from './domain/pricing.js';
import { validateClaim } from './domain/claims.js';
import { authorizeHold, captureHold, createHold, releaseHold } from './domain/holds.js';
import { buildOrder, cutoffDecision, isFilled } from './domain/cutoff.js';
import { istMonthKey, walletFor } from './domain/wallet.js';
import { bucketGroupId, streetGroupId } from './nexconn.js';
import { fmtTime, fmtWindow, rupees } from './format.js';

export const DEMO_OTP = '1234';
const PENDING_TTL_MS = 15 * 60_000;
const TYPES = new Set(['split', 'bulk', 'service', 'trip']);
const DEFAULT_UNIT = { split: 'share', bulk: 'kg', service: 'flat', trip: 'kg' };
const rid = (prefix, bytes = 4) => `${prefix}_${crypto.randomBytes(bytes).toString('hex')}`;
const releasable = (h) => h && (h.status === 'created' || h.status === 'held');

export class JugaadService {
  constructor({ store, nx, now = () => new Date(), rng = Math.random, logger = console, appKey = '' }) {
    this.store = store;
    this.nx = nx;
    this.now = now;
    this.rng = rng;
    this.logger = logger;
    this.appKey = appKey;
    this.queue = Promise.resolve();
  }

  // ---- background Nexconn work -------------------------------------------------------------
  bg(label, fn) {
    this.queue = this.queue.then(fn).catch((e) => this.logger.warn?.(`[bg] ${label}: ${e.message}`));
    return this.queue;
  }
  async flush() { let q; do { q = this.queue; await q; } while (q !== this.queue); }
  save() { this.store.save(); }

  // ---- views ---------------------------------------------------------------------------------
  publicUser(u) {
    if (!u) return null;
    const out = { id: u.id, name: u.name, phone: u.phone ?? null, kind: u.kind ?? 'member' };
    if (u.vendorId) out.vendorId = u.vendorId;
    return out;
  }

  communityView(c) {
    const month = istMonthKey(this.now());
    const saved = this.store.orders((o) => o.communityId === c.id && istMonthKey(o.createdAt) === month)
      .reduce((n, o) => n + o.lines.reduce((m, l) => m + (l.savings ?? 0), 0), 0);
    return {
      id: c.id, name: c.name, kind: c.kind, area: c.area, city: c.city, flats: c.flats, image: c.image,
      streetGroupId: streetGroupId(c.id),
      stats: {
        members: (c.baseMembers ?? 0) + this.store.membersOf(c.id).length,
        savedThisMonth: (c.baseSavedThisMonth ?? 0) + saved,
        liveBuckets: this.store.buckets((b) => b.communityId === c.id && b.status === 'live').length,
      },
    };
  }

  shareView(s, own = true) {
    const b = this.store.bucket(s.bucketId);
    const base = {
      id: s.id, bucketId: s.bucketId, user: s.user, qty: s.qty, qtyLabel: b ? P.qtyLabel(b, s) : '',
      unitIds: s.unitIds, items: s.items, options: s.options, payMode: s.payMode, status: s.status, createdAt: s.createdAt,
    };
    if (!own) return base;
    return {
      ...base, estAmount: s.estAmount, finalAmount: s.finalAmount,
      hold: s.hold ? { id: s.hold.id, amount: s.hold.amount, status: s.hold.status, vpa: s.hold.vpa } : null,
      otp: s.otp ?? null, orderId: s.orderId ?? null, createdAt: s.createdAt,
      savings: b && s.finalAmount != null ? P.savings(b, s, s.finalAmount) : null,
    };
  }

  bucketView(b, viewerId = null) {
    const shares = this.store.sharesOf(b.id);
    const active = shares.filter(P.isActive);
    const ownerOf = new Map();
    for (const s of active) for (const id of s.unitIds ?? []) ownerOf.set(id, s.user);
    const mine = shares.filter((s) => s.user.id === viewerId)
      .sort((x, y) => String(y.createdAt).localeCompare(String(x.createdAt)));
    const myShare = mine.find(P.isActive) ?? mine.find((s) => s.status === 'released') ?? null;
    return {
      ...b,
      vendor: b.vendor ?? null,
      units: b.type === 'split' ? b.units.map((u) => ({ ...u, owner: ownerOf.get(u.id) ?? null })) : null,
      tiers: b.tiers ?? null,
      items: b.type === 'trip' ? b.items.map((it) => {
        const using = active.filter((s) => s.items?.some((x) => x.id === it.id));
        return { ...it, qty: using.reduce((n, s) => n + s.items.find((x) => x.id === it.id).qty, 0), members: using.length };
      }) : null,
      capacity: b.capacity ?? null,
      progress: P.progress(b, shares),
      cardMessageId: b.cardMessageId ?? null,
      groupId: this.groupOf(b),
      myShare: myShare ? this.shareView(myShare, true) : null,
      shares: active.map((s) => this.shareView(s, false)),
    };
  }

  /** The bucket's Nexconn group: tagged with the seed so a re-seed never reuses an old group's history. */
  groupOf(b) { return b.groupId ?? bucketGroupId(b.id, this.store.data.seedTag ?? ''); }

  orderView(o, viewer) {
    const isMember = (l) => viewer && l.userId === viewer.id;
    const b = this.store.bucket(o.bucketId);
    return {
      ...o,
      groupId: b ? this.groupOf(b) : bucketGroupId(o.bucketId),
      lines: o.lines.map((l) => ({ ...l, otp: isMember(l) ? l.otp : null })),
      myLine: o.lines.find(isMember) ?? null,
    };
  }

  // ---- auth ----------------------------------------------------------------------------------
  normPhone(phone) {
    const d = String(phone ?? '').replace(/\D/g, '');
    const p = d.length > 10 ? d.slice(-10) : d;
    if (!/^[6-9]\d{9}$/.test(p)) fail('INVALID_PHONE', 'Enter a 10-digit mobile number.');
    return p;
  }

  requestOtp({ phone }) {
    this.normPhone(phone);
    return { ok: true, devCode: DEMO_OTP };
  }

  async verify({ phone, code, name }) {
    const p = this.normPhone(phone);
    if (String(code ?? '').trim() !== DEMO_OTP) fail('OTP_INVALID', 'That code is not right. (Demo code: 1234)');
    let user = this.store.userByPhone(p);
    if (!user) {
      const n = String(name ?? '').trim();
      if (!n) fail('NAME_REQUIRED', 'Tell us your name to create your account.');
      user = this.store.putUser({ id: rid('u'), name: n.slice(0, 40), phone: p, kind: 'member', createdAt: this.now().toISOString() });
    }
    const sessionToken = crypto.randomBytes(32).toString('hex');
    this.store.putSession(sessionToken, user.id);
    this.save();
    const token = await this.nexconnTokenFor(user);
    return { sessionToken, user: this.publicUser(user), nexconn: { appKey: this.appKey, token, userId: user.id } };
  }

  async nexconnTokenFor(user) {
    let t = this.store.nexconnToken(user.id);
    if (!t) {
      t = await this.nx.ensureUser(user.id, user.name);
      if (t) { this.store.putNexconnToken(user.id, t); this.save(); }
    }
    return t ?? null;
  }

  userForToken(token) { return token ? this.store.sessionUser(token) : null; }

  me(user) {
    return {
      user: this.publicUser(user),
      memberships: this.store.membershipsOf(user.id).map((m) => ({
        community: this.communityView(this.store.community(m.communityId)), unit: m.unit, role: m.role,
      })),
    };
  }

  /** Display profiles for chat (names, flat, role) — no phone numbers. */
  profiles(ids = []) {
    const BOT = { id: 'jugaad_bot', name: 'Jugaad Street', unit: null, kind: 'bot', label: 'Jugaad Street' };
    return ids.slice(0, 200).map((id) => {
      if (id === 'jugaad_bot') return BOT;
      const u = this.store.user(id);
      if (!u) return null;
      const vendor = this.store.vendorByUser(u.id);
      const m = this.store.membershipsOf(u.id)[0];
      const unit = m?.unit ?? null;
      const label = vendor ? `${vendor.name} · vendor` : unit ? `${u.name} · ${unit}` : u.name;
      return { id: u.id, name: vendor?.name ?? u.name, unit, kind: vendor ? 'vendor' : (m?.role ?? u.kind ?? 'member'), label };
    }).filter(Boolean);
  }

  // ---- communities ---------------------------------------------------------------------------
  communities(q = '') {
    const needle = String(q).trim().toLowerCase();
    return this.store.communities()
      .filter((c) => !needle || [c.name, c.area, c.city].some((x) => String(x ?? '').toLowerCase().includes(needle)))
      .map((c) => this.communityView(c));
  }

  community(id) {
    const c = this.store.community(id);
    if (!c) fail('NOT_FOUND', 'No such community.', 404);
    return this.communityView(c);
  }

  joinCommunity(user, id, { unit } = {}) {
    const c = this.store.community(id);
    if (!c) fail('NOT_FOUND', 'No such community.', 404);
    const u = String(unit ?? '').trim().toUpperCase();
    if (!u || u.length > 16) fail('BAD_REQUEST', 'Tell us your flat or unit, like B-1204.');
    let m = this.store.membership(user.id, id);
    if (m) m.unit = u;
    else m = this.store.addMembership({ userId: user.id, communityId: id, unit: u, role: 'member', joinedAt: this.now().toISOString() });
    this.save();
    this.bg('join street', async () => {
      await this.nexconnTokenFor(user);
      await this.nx.addToStreet(id, [user.id]);
    });
    return { membership: { community: this.communityView(c), unit: m.unit, role: m.role } };
  }

  requireMembership(user, communityId) {
    const m = this.store.membership(user.id, communityId);
    if (!m) fail('NOT_MEMBER', 'Join this community first.', 403);
    return m;
  }

  requireAdmin(user, communityId) {
    const m = this.store.membership(user.id, communityId);
    if (m?.role !== 'admin') fail('FORBIDDEN', 'Only the community admin can do this.', 403);
    return m;
  }

  // ---- buckets -------------------------------------------------------------------------------
  bucketOr404(id) {
    const b = this.store.bucket(id);
    if (!b) fail('NOT_FOUND', 'No such bucket.', 404);
    return b;
  }

  listBuckets(communityId, { category, type, status } = {}, viewerId = null) {
    if (!this.store.community(communityId)) fail('NOT_FOUND', 'No such community.', 404);
    const rank = (b) => (b.status === 'live' ? 0 : 1);
    return this.store.buckets((b) => b.communityId === communityId
      && (!category || b.category === category) && (!type || b.type === type)
      && (!status || status === 'all' || b.status === status))
      .sort((a, b) => rank(a) - rank(b) || (rank(a) === 0
        ? String(a.cutoffAt).localeCompare(String(b.cutoffAt))
        : String(b.cutoffAt).localeCompare(String(a.cutoffAt))))
      .map((b) => this.bucketView(b, viewerId));
  }

  getBucket(id, viewerId) { return this.bucketView(this.bucketOr404(id), viewerId); }

  createBucket(user, d = {}, { post = true } = {}) {
    const c = this.store.community(d.communityId);
    if (!c) fail('BAD_REQUEST', 'communityId is not a known community.');
    const m = this.requireMembership(user, c.id);
    if (!TYPES.has(d.type)) fail('BAD_REQUEST', 'type must be split, bulk, service or trip.');
    const title = String(d.title ?? '').trim();
    if (!title) fail('BAD_REQUEST', 'Give the bucket a title.');
    const cutoff = new Date(d.cutoffAt);
    if (Number.isNaN(cutoff.getTime()) || cutoff <= this.now()) fail('BAD_REQUEST', 'cutoffAt must be a future time.');
    const settleMode = d.settleMode ?? 'hold';
    if (!['hold', 'at_market'].includes(settleMode)) fail('BAD_REQUEST', 'settleMode must be hold or at_market.');
    const int = (v, what) => { if (!Number.isInteger(v) || v < 0) fail('BAD_REQUEST', `${what} must be whole rupees.`); return v; };

    let units = null; let tiers = null; let items = null;
    if (d.type === 'split') {
      if (!Array.isArray(d.units) || !d.units.length) fail('BAD_REQUEST', 'A split bucket needs units.');
      const ids = new Set();
      units = d.units.map((u, i) => {
        const id = String(u.id ?? `u${i + 1}`);
        if (ids.has(id)) fail('BAD_REQUEST', `Duplicate unit id ${id}.`);
        ids.add(id);
        return { id, label: String(u.label ?? `Share ${i + 1}`), grams: u.grams ?? null, price: int(u.price, 'Unit price') };
      });
    } else if (d.type === 'bulk' || d.type === 'service') {
      if (!Array.isArray(d.tiers) || !d.tiers.length) fail('BAD_REQUEST', 'Bulk and service buckets need price tiers.');
      tiers = d.tiers.map((t) => ({ minQty: Number(t.minQty), unitPrice: int(t.unitPrice, 'Tier price') }))
        .sort((a, b) => a.minQty - b.minQty);
      if (tiers.some((t) => !(t.minQty > 0))) fail('BAD_REQUEST', 'Tier minQty must be above 0.');
    } else {
      if (!Array.isArray(d.items) || !d.items.length) fail('BAD_REQUEST', 'A trip needs a list of items.');
      if (!(Number(d.capacity) > 0)) fail('BAD_REQUEST', 'A trip needs a capacity in kg.');
      items = d.items.map((it, i) => ({
        id: String(it.id ?? `i${i + 1}`), name: String(it.name ?? `Item ${i + 1}`), unit: it.unit ?? 'kg',
        price: int(it.price, 'Item price'), kgPerUnit: it.kgPerUnit ?? 1, retailPrice: it.retailPrice ?? null,
      }));
    }
    const vendor = d.vendorId ? this.store.vendor(d.vendorId) : this.store.vendorByUser(user.id);
    const now = this.now();
    const b = {
      id: d.id ?? rid('b', 3), communityId: c.id, type: d.type, category: d.category ?? 'other',
      title, subtitle: d.subtitle ?? '', image: d.image ?? d.category ?? d.type,
      vendor: vendor ? { id: vendor.id, name: vendor.name, place: vendor.place, rating: vendor.rating } : null,
      createdBy: { id: user.id, name: user.name, unit: m.unit },
      settleMode, meet: d.meet ?? null, cutoffAt: cutoff.toISOString(),
      deliverAt: d.deliverAt ? new Date(d.deliverAt).toISOString() : new Date(cutoff.getTime() + 12 * 3600_000).toISOString(),
      pickupPoint: d.pickupPoint ?? 'Main gate', unitLabel: d.unitLabel ?? DEFAULT_UNIT[d.type],
      retailUnitPrice: d.retailUnitPrice ?? null, unitPrice: d.unitPrice ?? null,
      netWeight: d.netWeight ?? null, serves: d.serves ?? null, description: d.description ?? null,
      units, tiers, items,
      capacity: d.type === 'trip' ? Number(d.capacity) : null,
      minLoadKg: d.type === 'trip' ? Number(d.minLoadKg ?? Math.round(Number(d.capacity) / 2)) : undefined,
      transportFee: d.type === 'trip' ? int(d.transportFee ?? 0, 'transportFee') : undefined,
      minQty: d.minQty ?? null, maxQty: d.maxQty ?? null, lotQty: d.lotQty ?? null,
      maxUnitsPerMember: d.maxUnitsPerMember ?? null, optionGroups: d.optionGroups ?? null,
      status: 'live', cardMessageId: null, orderId: null, createdAt: now.toISOString(),
    };
    this.store.putBucket(b);
    this.save();
    if (post) this.postCard(b);
    return this.bucketView(b, user.id);
  }

  postCard(b) {
    return this.bg(`card ${b.id}`, async () => {
      const id = await this.nx.postBucketCard(this.bucketView(b));
      if (id) { b.cardMessageId = id; this.save(); }
    });
  }

  // Runs on the queue, after any pending card post has stored its cardMessageId. The view is built at
  // send time, so a burst of changes still ends with the latest state on the card.
  syncCard(b) {
    this.bg(`metadata ${b.id}`, () => (b.cardMessageId ? this.nx.updateCard(this.bucketView(b)) : null));
  }

  event(b, kind, text, actor = 'jugaad_bot', groupId = streetGroupId(b.communityId)) {
    this.bg(`event ${kind} ${b.id}`, () => this.nx.postEvent(groupId, { bucketId: b.id, kind, text, actor }));
  }

  // ---- shares & holds ------------------------------------------------------------------------
  joinBucket(user, bucketId, body = {}) {
    const b = this.bucketOr404(bucketId);
    const m = this.requireMembership(user, b.communityId);
    const shares = this.store.sharesOf(b.id);
    const claim = validateClaim(b, shares, user.id, body, this.now());
    const est = P.quoteClaim(b, claim, shares.filter(P.isCommitted));
    const now = this.now();
    const share = this.store.putShare({
      id: rid('s'), bucketId: b.id, user: { id: user.id, name: user.name, unit: m.unit },
      qty: claim.qty, unitIds: claim.unitIds, items: claim.items, options: claim.options,
      payMode: claim.payMode, estAmount: est, finalAmount: null,
      status: claim.payMode === 'hold' ? 'pending_payment' : 'booked',
      hold: claim.payMode === 'hold' ? createHold(rid('h'), est, now) : null,
      otp: null, orderId: null, createdAt: now.toISOString(),
    });
    if (share.status === 'booked') this.afterCommit(b, share);
    else this.syncCard(b); // split cards show reserved parts straight away
    this.save();
    return { share: this.shareView(share), bucket: this.bucketView(b, user.id) };
  }

  authorizeHold(user, holdId, body = {}) {
    const share = this.store.shareByHold(holdId);
    if (!share) fail('NOT_FOUND', 'No such payment hold.', 404);
    if (share.user.id !== user.id) fail('FORBIDDEN', 'This hold belongs to someone else.', 403);
    const b = this.bucketOr404(share.bucketId);
    if (share.hold.status === 'created' && (b.status !== 'live' || share.status !== 'pending_payment')) {
      fail('BUCKET_CLOSED', 'This bucket is closed, so nothing was blocked.', 409);
    }
    share.hold = authorizeHold(share.hold, body, this.now());
    share.status = 'held';
    this.afterCommit(b, share);
    this.save();
    return { share: this.shareView(share), bucket: this.bucketView(b, user.id) };
  }

  afterCommit(b, share) {
    const shares = this.store.sharesOf(b.id);
    let text = `${share.user.name} (${share.user.unit}) took ${P.qtyLabel(b, share)}`;
    if (b.type === 'bulk' || b.type === 'service') {
      const committed = shares.filter(P.isCommitted);
      const after = P.sumQty(b, committed);
      const before = after - P.shareQty(b, share);
      const pAfter = P.unitPriceAt(b, after);
      if (P.tierFor(b.tiers, after) && pAfter < P.unitPriceAt(b, before)) {
        text += ` and unlocked ${rupees(pAfter)}/${b.unitLabel} for everyone!`;
      } else if (before < P.goAt(b) && after >= P.goAt(b)) {
        text += `. The bucket is on: it goes ahead at the cutoff.`;
      }
    }
    if (share.payMode === 'at_market') text += ' (pays at the market)';
    this.event(b, 'joined', text, share.user.id);
    if (isFilled(b, shares)) this.lockBucket(b);
    else this.syncCard(b);
  }

  leaveShare(user, shareId) {
    const share = this.store.share(shareId);
    if (!share) fail('NOT_FOUND', 'No such share.', 404);
    if (share.user.id !== user.id) fail('FORBIDDEN', 'This share belongs to someone else.', 403);
    const b = this.bucketOr404(share.bucketId);
    if (b.status !== 'live' || !['pending_payment', 'held', 'booked'].includes(share.status)) {
      fail('SHARE_LOCKED', 'This share is locked into an order and cannot be cancelled.', 409);
    }
    const wasCommitted = P.isCommitted(share);
    if (releasable(share.hold)) share.hold = releaseHold(share.hold, this.now());
    share.status = 'left';
    share.leftAt = this.now().toISOString();
    if (wasCommitted) {
      const freed = share.hold?.heldAt ? ` ${rupees(share.hold.amount)} hold released.` : '';
      this.event(b, 'left', `${share.user.name} left: ${P.qtyLabel(b, share)} is open again.${freed}`, user.id);
    }
    this.syncCard(b);
    this.save();
    return { bucket: this.bucketView(b, user.id) };
  }

  checkin(user, shareId) {
    const share = this.store.share(shareId);
    if (!share) fail('NOT_FOUND', 'No such share.', 404);
    if (share.user.id !== user.id) fail('FORBIDDEN', 'This share belongs to someone else.', 403);
    const b = this.bucketOr404(share.bucketId);
    if (!['ordered', 'market_day', 'delivering'].includes(b.status) || !['booked', 'captured'].includes(share.status)) {
      fail('BAD_STATE', 'You can check in once the bucket is confirmed.', 409);
    }
    share.status = 'checked_in';
    share.checkedInAt = this.now().toISOString();
    const where = b.meet?.place ?? b.pickupPoint;
    this.event(b, 'checkin', `${share.user.name} (${share.user.unit}) is here at ${where}`, user.id, this.groupOf(b));
    this.save();
    return { share: this.shareView(share), bucket: this.bucketView(b, user.id) };
  }

  // ---- cutoff, lock, expire -----------------------------------------------------------------
  closeBucket(bucketId) {
    const b = this.bucketOr404(bucketId);
    if (b.status !== 'live') fail('BUCKET_CLOSED', `This bucket is already ${b.status}.`, 409);
    const order = this.processCutoff(b);
    return { bucket: this.bucketView(b), order: order ?? null };
  }

  processCutoff(b) {
    return cutoffDecision(b, this.store.sharesOf(b.id)) === 'order' ? this.lockBucket(b) : (this.expireBucket(b), null);
  }

  lockBucket(b) {
    const now = this.now();
    const shares = this.store.sharesOf(b.id);
    const { order, release } = buildOrder(b, shares, { orderId: this.store.nextOrderId(), now, rng: this.rng, window: fmtWindow(b) });
    for (const line of order.lines) {
      const s = this.store.share(line.shareId);
      Object.assign(s, { finalAmount: line.amount, otp: line.otp, orderId: order.id, orderedAt: now.toISOString() });
      if (s.payMode === 'hold') { s.hold = captureHold(s.hold, line.amount, now); s.status = 'captured'; }
    }
    for (const id of release) {
      const s = this.store.share(id);
      if (releasable(s.hold)) s.hold = releaseHold(s.hold, now);
      s.status = 'released';
    }
    b.status = b.settleMode === 'at_market' ? 'market_day' : 'ordered';
    b.orderId = order.id;
    b.closedAt = now.toISOString();
    this.store.putOrder(order);
    this.save();

    const vendorUser = b.vendor ? this.store.vendor(b.vendor.id)?.userId : null;
    const memberIds = [...new Set([...order.lines.map((l) => l.userId), ...(vendorUser ? [vendorUser] : [])])];
    const savedTotal = order.lines.reduce((n, l) => n + l.savings, 0);
    const how = b.settleMode === 'at_market' ? `Meet ${fmtWindow(b)}.` : `${rupees(order.heldTotal)} captured, every hold was at or above the final price.`;
    this.event(b, 'locked', `${b.title} is confirmed! Order ${order.id} for ${order.lines.length} neighbours. ${how} Together you saved ${rupees(savedTotal)}.`);
    this.syncCard(b);
    this.bg(`order group ${b.id}`, async () => {
      b.groupId = this.groupOf(b);
      const ok = await this.nx.createBucketGroup(b, memberIds);
      if (!ok) return;
      await this.nx.postOrder(this.groupOf(b), order);
      await this.nx.postEvent(this.groupOf(b), {
        bucketId: b.id, kind: 'locked', actor: 'jugaad_bot',
        text: `Welcome to the ${b.title} group. Pickup: ${order.pickupPoint}, ${order.window}. Show your OTP to ${b.vendor?.name ?? 'the organiser'} at handover.`,
      });
      for (const line of order.lines) {
        await this.nx.sendOtp(line.userId, { orderId: order.id, otp: line.otp, pickupPoint: order.pickupPoint, window: order.window });
      }
    });
    return order;
  }

  expireBucket(b) {
    const now = this.now();
    let released = 0;
    for (const s of this.store.sharesOf(b.id).filter(P.isActive)) {
      if (releasable(s.hold)) {
        if (s.hold.status === 'held') released += s.hold.amount;
        s.hold = releaseHold(s.hold, now);
      }
      s.status = 'released';
      s.releasedAt = now.toISOString();
    }
    b.status = 'expired';
    b.closedAt = now.toISOString();
    this.save();
    const money = released ? ` All ${rupees(released)} held has been released. Nobody paid.` : ' Nobody paid.';
    this.event(b, 'expired', `${b.title} didn't fill by the cutoff.${money}`);
    this.syncCard(b);
    return released;
  }

  /** Scheduler tick: run due cutoffs and drop unpaid claims older than 15 minutes. */
  runCutoffs() {
    const now = this.now();
    const done = [];
    for (const b of this.store.buckets((x) => x.status === 'live')) {
      let touched = false;
      for (const s of this.store.sharesOf(b.id)) {
        if (s.status === 'pending_payment' && now - new Date(s.createdAt) > PENDING_TTL_MS) {
          s.hold = releaseHold(s.hold, now);
          s.status = 'released';
          s.releasedAt = now.toISOString();
          touched = true;
        }
      }
      if (new Date(b.cutoffAt) <= now) {
        const order = this.processCutoff(b);
        done.push({ bucketId: b.id, result: order ? `order ${order.id}` : 'expired' });
      } else if (touched) { this.syncCard(b); this.save(); }
    }
    return done;
  }

  // ---- orders --------------------------------------------------------------------------------
  canManageOrder(user, o) {
    const v = this.store.vendorByUser(user.id);
    if (v && v.id === o.vendorId) return true;
    const b = this.store.bucket(o.bucketId);
    if (b?.createdBy?.id === user.id) return true;
    return this.store.membership(user.id, o.communityId)?.role === 'admin';
  }

  getOrder(user, id) {
    const o = this.store.order(id);
    if (!o) fail('NOT_FOUND', 'No such order.', 404);
    if (!o.lines.some((l) => l.userId === user.id) && !this.canManageOrder(user, o)) fail('FORBIDDEN', 'This is not your order.', 403);
    return this.orderView(o, user);
  }

  myOrders(user) {
    return this.store.orders((o) => o.lines.some((l) => l.userId === user.id))
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt)).map((o) => this.orderView(o, user));
  }

  handover(user, orderId, { otp } = {}) {
    const o = this.store.order(orderId);
    if (!o) fail('NOT_FOUND', 'No such order.', 404);
    if (!this.canManageOrder(user, o)) fail('FORBIDDEN', 'Only the vendor can confirm handover.', 403);
    const line = o.lines.find((l) => l.otp === String(otp ?? '').trim());
    if (!line) fail('OTP_INVALID', 'That OTP does not match anyone in this order.');
    if (line.collected) fail('ALREADY_COLLECTED', `${line.name} has already collected.`, 409);
    const now = this.now().toISOString();
    Object.assign(line, { collected: true, collectedAt: now });
    if (line.payMode === 'at_market') line.paymentStatus = 'paid';
    const s = this.store.share(line.shareId);
    if (s) Object.assign(s, { status: 'collected', collectedAt: now });
    const b = this.store.bucket(o.bucketId);
    if (o.lines.every((l) => l.collected)) { o.status = 'delivered'; if (b) b.status = 'completed'; } else if (b) b.status = 'delivering';
    this.save();
    if (b) this.syncCard(b);
    return { order: this.orderView(o, user) };
  }

  wallet(user) { return walletFor(this.store.sharesByUser(user.id), this.store.data.buckets, this.now()); }

  // ---- vendor & admin ------------------------------------------------------------------------
  vendorDashboard(user) {
    const v = this.store.vendorByUser(user.id);
    if (!v) fail('NOT_VENDOR', 'This account is not a vendor.', 403);
    const buckets = this.store.buckets((b) => b.vendor?.id === v.id)
      .sort((a, b) => (a.status === 'live' ? 0 : 1) - (b.status === 'live' ? 0 : 1) || a.cutoffAt.localeCompare(b.cutoffAt))
      .map((b) => this.bucketView(b, user.id));
    const heldDemand = buckets.filter((b) => b.status === 'live').reduce((n, b) => n + b.progress.held, 0);
    const groups = new Map();
    for (const o of this.store.orders((x) => x.vendorId === v.id && x.status !== 'delivered')) {
      const c = this.store.community(o.communityId);
      const key = c?.id ?? o.communityId;
      if (!groups.has(key)) groups.set(key, { communityId: key, communityName: c?.name ?? key, lines: [] });
      for (const l of o.lines) groups.get(key).lines.push({ ...l, otp: null, orderId: o.id, title: o.title });
    }
    return { vendor: v, heldDemand, buckets, packing: [...groups.values()] };
  }

  nudgeText(b) {
    const shares = this.store.sharesOf(b.id);
    const filled = P.sumQty(b, shares.filter(P.isCommitted));
    const when = fmtTime(b.cutoffAt);
    if (b.type === 'split') {
      const taken = new Set(shares.filter(P.isActive).flatMap((s) => s.unitIds ?? []));
      const open = b.units.filter((u) => !taken.has(u.id)).map((u) => u.label);
      const list = open.length > 1 ? `${open.slice(0, -1).join(', ')} and ${open.at(-1)}` : open[0];
      return `${b.title}: ${list} ${open.length > 1 ? 'are' : 'is'} still open. ${P.plural(open.length, b.unitLabel)} left before ${when}.`;
    }
    if (b.type === 'trip') return `${b.title} has room for ${Math.round(b.capacity - filled)} kg more. Add your list before ${when}.`;
    const go = P.goAt(b);
    if (filled < go) return `${b.title} needs ${P.plural(go - filled, b.unitLabel)} more to go ahead. Cutoff ${when}.`;
    const next = P.nextTier(b.tiers, filled);
    if (next) return `${b.title}: ${P.plural(next.remaining, b.unitLabel)} more unlocks ${rupees(next.unitPrice)}/${b.unitLabel} for everyone. Cutoff ${when}.`;
    return `${b.title} is at its best price, ${rupees(P.unitPriceAt(b, filled))}/${b.unitLabel}. Join before ${when}.`;
  }

  adminCommunity(user, id) {
    const c = this.store.community(id);
    if (!c) fail('NOT_FOUND', 'No such community.', 404);
    this.requireAdmin(user, id);
    const view = this.communityView(c);
    const nudges = this.store.buckets((b) => b.communityId === id && b.status === 'live' && !isFilled(b, this.store.sharesOf(b.id)))
      .sort((a, b) => a.cutoffAt.localeCompare(b.cutoffAt))
      .map((b) => ({ bucketId: b.id, title: b.title, cutoffAt: b.cutoffAt, text: this.nudgeText(b) }));
    return { community: view, savedThisMonth: view.stats.savedThisMonth, members: view.stats.members, pendingVendors: c.pendingVendors ?? [], nudges };
  }

  nudge(user, { bucketId } = {}) {
    const b = this.bucketOr404(bucketId);
    if (b.createdBy?.id !== user.id) this.requireAdmin(user, b.communityId);
    if (b.status !== 'live') fail('BUCKET_CLOSED', 'This bucket is closed.', 409);
    const text = this.nudgeText(b);
    this.event(b, 'nudge', text, user.id);
    return { ok: true, text };
  }

  async health() {
    const s = await this.nx.health();
    return { ok: true, nexconn: s === 'ok' ? 'ok' : 'error', nexconnDetail: s };
  }
}
