// JSON file store: whole DB in memory, atomic writes (temp file + rename). file=null → memory only.
import fs from 'node:fs';
import path from 'node:path';

export function emptyDb() {
  return {
    version: 1, seededAt: null,
    users: {}, sessions: {}, nexconnTokens: {},
    communities: {}, memberships: [], vendors: {},
    buckets: {}, shares: {}, orders: {},
    // Order numbers keep climbing across re-seeds: Nexconn keeps chat history, so a reset would repeat JS-2041.
    counters: { order: 2040 + (Math.floor(Date.now() / 60000) % 7000) },
  };
}

export class Store {
  constructor(file = null, data = null) {
    this.file = file;
    this.data = data ?? Store.read(file) ?? emptyDb();
  }

  static read(file) {
    if (!file || !fs.existsSync(file)) return null;
    try { return JSON.parse(fs.readFileSync(file, 'utf8')); } catch (e) {
      console.warn(`[store] could not parse ${path.basename(file)} (${e.message}); starting empty`);
      return null;
    }
  }

  get isEmpty() { return !this.data.seededAt && Object.keys(this.data.users).length === 0; }

  replace(data) { this.data = data; this.save(); }

  save() {
    if (!this.file) return;
    fs.mkdirSync(path.dirname(this.file), { recursive: true });
    const tmp = `${this.file}.${process.pid}.tmp`;
    fs.writeFileSync(tmp, JSON.stringify(this.data));
    fs.renameSync(tmp, this.file);
  }

  nextOrderId() { this.data.counters.order += 1; return `JS-${this.data.counters.order}`; }

  // ---- repository helpers ------------------------------------------------------------------
  user(id) { return this.data.users[id] ?? null; }
  userByPhone(phone) { return Object.values(this.data.users).find((u) => u.phone === phone) ?? null; }
  putUser(u) { this.data.users[u.id] = u; return u; }

  sessionUser(token) { const id = this.data.sessions[token]; return id ? this.user(id) : null; }
  putSession(token, userId) { this.data.sessions[token] = userId; }

  nexconnToken(userId) { return this.data.nexconnTokens[userId] ?? null; }
  putNexconnToken(userId, token) { this.data.nexconnTokens[userId] = token; }

  community(id) { return this.data.communities[id] ?? null; }
  communities() { return Object.values(this.data.communities); }
  membershipsOf(userId) { return this.data.memberships.filter((m) => m.userId === userId); }
  membersOf(communityId) { return this.data.memberships.filter((m) => m.communityId === communityId); }
  membership(userId, communityId) {
    return this.data.memberships.find((m) => m.userId === userId && m.communityId === communityId) ?? null;
  }
  addMembership(m) { this.data.memberships.push(m); return m; }

  vendor(id) { return this.data.vendors[id] ?? null; }
  vendorByUser(userId) { return Object.values(this.data.vendors).find((v) => v.userId === userId) ?? null; }

  bucket(id) { return this.data.buckets[id] ?? null; }
  buckets(pred = () => true) { return Object.values(this.data.buckets).filter(pred); }
  putBucket(b) { this.data.buckets[b.id] = b; return b; }

  share(id) { return this.data.shares[id] ?? null; }
  sharesOf(bucketId) { return Object.values(this.data.shares).filter((s) => s.bucketId === bucketId); }
  sharesByUser(userId) { return Object.values(this.data.shares).filter((s) => s.user.id === userId); }
  shareByHold(holdId) { return Object.values(this.data.shares).find((s) => s.hold?.id === holdId) ?? null; }
  putShare(s) { this.data.shares[s.id] = s; return s; }

  order(id) { return this.data.orders[id] ?? null; }
  orders(pred = () => true) { return Object.values(this.data.orders).filter(pred); }
  putOrder(o) { this.data.orders[o.id] = o; return o; }
}
