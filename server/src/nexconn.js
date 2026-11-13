// Small signed client for the Nexconn server API (Singapore) plus Jugaad Street helpers.
// Never logs the App Secret, signatures or user tokens.
import crypto from 'node:crypto';

export const NEXCONN_HOSTS = ['https://api.sg-light-api.com', 'https://api-b.sg-light-api.com'];
export const BOT_ID = 'jugaad_bot';
export const BOT_NAME = 'Jugaad Street';
const CHANNEL_GROUP = 3;
// "Group channel ID already exists" (HTTP 400, verified live). 25410 = group does not exist.
const GROUP_EXISTS_CODES = new Set([25409]);

export class NexconnError extends Error {
  constructor(message, { code = null, httpStatus = null, path = '', retryable = false } = {}) {
    super(message);
    this.name = 'NexconnError';
    this.code = code;
    this.httpStatus = httpStatus;
    this.path = path;
    this.retryable = retryable;
  }
}

export const streetGroupId = (communityId) => `street_${communityId}`;
/** Bucket group id. A seed tag makes every re-seed use brand-new groups (Nexconn keeps group history per id). */
export const bucketGroupId = (bucketId, tag = '') => (tag ? `bucket_${bucketId}__${tag}` : `bucket_${bucketId}`);

const str = (v) => (v === null || v === undefined ? '' : typeof v === 'string' ? v : typeof v === 'object' ? JSON.stringify(v) : String(v));
const strings = (obj) => Object.fromEntries(Object.entries(obj).map(([k, v]) => [k, str(v)]));
const chunk = (arr, n) => { const out = []; for (let i = 0; i < arr.length; i += n) out.push(arr.slice(i, i + n)); return out; };
const initial = (name) => (name ? [...name.trim()][0]?.toUpperCase() || '' : '');

/** Card metadata for a bucket view (see docs/CONTRACT.md "Nexconn chat contract"). */
export function cardMetadata(view) {
  const meta = { p: JSON.stringify(view.progress), s: view.status };
  if (view.type === 'split' && Array.isArray(view.units)) {
    meta.u = JSON.stringify(view.units.map((u) => [u.id, u.owner ? initial(u.owner.name) : '']));
  }
  for (const [k, v] of Object.entries(meta)) {
    if (k.length > 32) throw new Error(`metadata key too long: ${k}`);
    if (v.length > 4096) throw new Error(`metadata value too long: ${k}`);
  }
  return meta;
}

export function cardContent(view) {
  return strings({
    bucketId: view.id, type: view.type, title: view.title, subtitle: view.subtitle, image: view.image,
    vendor: view.vendor ? view.vendor.name : '', cutoffAt: view.cutoffAt, unitLabel: view.unitLabel,
  });
}

/**
 * createNexconn({appKey, appSecret}) → client. With `disabled:true` (or missing keys) every helper is a
 * no-op that returns null, so the API keeps working offline.
 */
export function createNexconn({
  appKey, appSecret, hosts = NEXCONN_HOSTS, fetchImpl = globalThis.fetch, timeoutMs = 8000,
  logger = console, disabled = false,
} = {}) {
  const enabled = !disabled && Boolean(appKey && appSecret);
  const state = { status: enabled ? 'unknown' : 'disabled', lastError: null, lastOkAt: null, lastProbeAt: 0 };

  function sign() {
    const nonce = crypto.randomBytes(8).toString('hex');
    const ts = Date.now().toString();
    const signature = crypto.createHash('sha1').update(appSecret + nonce + ts).digest('hex');
    return { 'App-Key': appKey, Nonce: nonce, Timestamp: ts, Signature: signature, 'Content-Type': 'application/json' };
  }

  async function call(path, body) {
    if (!enabled) throw new NexconnError('Nexconn disabled', { path });
    let lastErr;
    for (const host of hosts) {
      try {
        const res = await fetchImpl(host + path, {
          method: 'POST', headers: sign(), body: JSON.stringify(body), signal: AbortSignal.timeout(timeoutMs),
        });
        const text = await res.text();
        let json;
        try { json = JSON.parse(text); } catch { json = null; }
        if (res.status >= 500 || !json) {
          lastErr = new NexconnError(`HTTP ${res.status} from ${path}`, { httpStatus: res.status, path, retryable: true });
          continue;
        }
        if (json.code !== 0) {
          throw new NexconnError(json.msg || json.message || json.errorMessage || `code ${json.code}`, { code: json.code, httpStatus: res.status, path });
        }
        state.status = 'ok'; state.lastOkAt = Date.now(); state.lastError = null;
        return json;
      } catch (e) {
        if (e instanceof NexconnError && !e.retryable) {
          // An API-level rejection still proves the service is reachable.
          state.status = 'ok'; state.lastOkAt = Date.now();
          throw e;
        }
        lastErr = e instanceof NexconnError ? e : new NexconnError(`${e.name}: ${e.message}`, { path, retryable: true });
      }
    }
    state.status = 'error'; state.lastError = lastErr.message;
    throw lastErr;
  }

  // Wraps a helper: failures become a short warning and a null result, so callers never break.
  function safe(name, fn) {
    return async (...args) => {
      if (!enabled) return null;
      try { return await fn(...args); } catch (e) {
        logger.warn?.(`[nexconn] ${name} failed: ${e.code ?? ''} ${e.message}`.replace(/\s+/g, ' '));
        return null;
      }
    };
  }

  // ---- raw endpoints ------------------------------------------------------------------------
  async function issueToken(userId, name) {
    const r = await call('/v4/auth/access-token/issue', { userId, name: (name || userId).slice(0, 64) });
    return r.result?.accessToken ?? null;
  }
  async function createGroupRaw(channelId, name, owner, userIds = []) {
    const [first = [], ...rest] = chunk(userIds.filter((u) => u !== owner), 30);
    await call('/v4/group-channel/create', { channelId, name: name.slice(0, 64), owner, userIds: first });
    for (const ids of rest) await call('/v4/group-channel/join', { channelId, userIds: ids });
  }
  async function joinRaw(channelId, userIds) {
    for (const ids of chunk([...new Set(userIds)], 100)) await call('/v4/group-channel/join', { channelId, userIds: ids });
  }
  async function sendGroup({ from = BOT_ID, channelId, type, content, pushContent, hasMetadata = false, metadata }) {
    const body = { fromUserId: from, toChannelIds: [channelId], messageType: type, content: JSON.stringify(content) };
    if (pushContent) body.pushContent = pushContent;
    if (hasMetadata) { body.hasMetadata = true; if (metadata) body.metadata = metadata; }
    const r = await call('/v4/group-channel/message/send', body);
    return r.result?.messageIds?.[0]?.messageId ?? null;
  }
  async function sendDirect({ from = BOT_ID, toUserIds, type, content, pushContent }) {
    const body = { fromUserId: from, toUserIds, messageType: type, content: JSON.stringify(content) };
    if (pushContent) body.pushContent = pushContent;
    const r = await call('/v4/direct-channel/message/send', body);
    return r.result?.messageIds?.[0]?.messageId ?? null;
  }
  async function setMetadata(channelId, messageId, metadata) {
    await call('/v4/channel-type/message/metadata/set', { messageId, userId: BOT_ID, channelType: CHANNEL_GROUP, channelId, metadata });
    return true;
  }

  async function ensureGroup(channelId, name, memberIds) {
    try {
      await createGroupRaw(channelId, name, BOT_ID, memberIds);
      return { created: true };
    } catch (e) {
      if (!(e instanceof NexconnError) || e.retryable || e.code === null) throw e;
      // Most likely "group already exists": just make sure everyone is in it.
      if (!GROUP_EXISTS_CODES.has(e.code)) logger.warn?.(`[nexconn] create ${channelId} → code ${e.code}; joining instead`);
      if (memberIds.length) await joinRaw(channelId, memberIds);
      return { created: false };
    }
  }

  // ---- Jugaad Street helpers (all failure-safe) ---------------------------------------------
  const api = {
    get enabled() { return enabled; },
    state,
    call,
    ensureUser: safe('ensureUser', (id, name) => issueToken(id, name)),
    ensureStreet: safe('ensureStreet', (community, memberIds = []) =>
      ensureGroup(streetGroupId(community.id), `${community.name} · Street`, memberIds)),
    addToStreet: safe('addToStreet', async (communityId, userIds) => { await joinRaw(streetGroupId(communityId), userIds); return true; }),
    postBucketCard: safe('postBucketCard', (view) => sendGroup({
      channelId: streetGroupId(view.communityId), type: 'js:bucket', content: cardContent(view),
      pushContent: `New bucket: ${view.title}`, hasMetadata: true, metadata: cardMetadata(view),
    })),
    updateCard: safe('updateCard', (view) => {
      if (!view.cardMessageId) return null;
      return setMetadata(streetGroupId(view.communityId), view.cardMessageId, cardMetadata(view));
    }),
    postEvent: safe('postEvent', (groupId, fields) => sendGroup({
      channelId: groupId, type: 'js:event',
      content: strings({ bucketId: fields.bucketId, kind: fields.kind, text: fields.text, actor: fields.actor }),
      pushContent: fields.push || undefined,
    })),
    createBucketGroup: safe('createBucketGroup', (bucket, memberIds) =>
      ensureGroup(bucket.groupId ?? bucketGroupId(bucket.id), bucket.title, memberIds)),
    postOrder: safe('postOrder', (groupId, order) => sendGroup({
      channelId: groupId, type: 'js:order', pushContent: `Order ${order.id} is confirmed`,
      content: strings({ orderId: order.id, bucketId: order.bucketId, title: order.title, total: order.total, members: order.lines.length }),
    })),
    sendOtp: safe('sendOtp', (userId, { orderId, otp, pickupPoint, window }) => sendDirect({
      toUserIds: [userId], type: 'js:otp', pushContent: 'Your pickup OTP is ready',
      content: strings({ orderId, otp, pickupPoint, window }),
    })),
    sendText: safe('sendText', (groupId, text, from = BOT_ID) => sendGroup({
      from, channelId: groupId, type: 'RC:TxtMsg', content: { content: text },
    })),
    /** Live probe, cached for 60 s. */
    async health() {
      if (!enabled) return 'disabled';
      if (Date.now() - state.lastProbeAt < 60_000 && state.status !== 'unknown') return state.status;
      state.lastProbeAt = Date.now();
      try { await issueToken(BOT_ID, BOT_NAME); } catch { /* state already updated */ }
      return state.status === 'ok' ? 'ok' : 'error';
    },
  };
  return api;
}
