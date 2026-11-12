// Dev helper for the Nexconn server API (SG). Reads ../.env. Never prints secrets.
// Usage: node scripts/nexconn-dev.mjs <cmd> [args]
//   token <userId> <name>                 issue a user token (prints it — dev only)
//   group <groupId> <name> <owner> <ids…>  create a group
//   join <groupId> <ids…>                  add members
//   card <groupId> <json-fields> <json-meta>  send js:bucket card from jugaad_bot with metadata
//   meta <groupId> <messageId> <json-meta> set metadata on a message
//   text <groupId> <text>                  send RC:TxtMsg from jugaad_bot
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import url from 'node:url';
const root = path.resolve(path.dirname(url.fileURLToPath(import.meta.url)), '..');
for (const line of fs.readFileSync(path.join(root, '.env'), 'utf8').split('\n')) {
  const m = line.match(/^([A-Z_]+)=(.*)$/); if (m && !process.env[m[1]]) process.env[m[1]] = m[2];
}
const BASE = 'https://api.sg-light-api.com';
async function call(p, body) {
  const nonce = crypto.randomBytes(8).toString('hex'), ts = Date.now().toString();
  const sig = crypto.createHash('sha1').update(process.env.NEXCONN_APP_SECRET + nonce + ts).digest('hex');
  const r = await fetch(BASE + p, { method: 'POST', headers: { 'App-Key': process.env.NEXCONN_APP_KEY, Nonce: nonce, Timestamp: ts, Signature: sig, 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  const t = await r.text(); let j; try { j = JSON.parse(t) } catch { j = t }
  return { status: r.status, body: j };
}
const [cmd, ...a] = process.argv.slice(2);
const out = (x) => console.log(JSON.stringify(x, null, 1));
if (cmd === 'token') out(await call('/v4/auth/access-token/issue', { userId: a[0], name: a[1] || a[0] }));
else if (cmd === 'group') out(await call('/v4/group-channel/create', { channelId: a[0], name: a[1], owner: a[2], userIds: a.slice(3) }));
else if (cmd === 'join') out(await call('/v4/group-channel/join', { channelId: a[0], userIds: a.slice(1) }));
else if (cmd === 'card') out(await call('/v4/group-channel/message/send', { fromUserId: 'jugaad_bot', toChannelIds: [a[0]], messageType: 'js:bucket', content: a[1], pushContent: 'New bucket on your street', hasMetadata: true, metadata: JSON.parse(a[2]) }));
else if (cmd === 'meta') out(await call('/v4/channel-type/message/metadata/set', { messageId: a[1], userId: 'jugaad_bot', channelType: 3, channelId: a[0], metadata: JSON.parse(a[2]) }));
else if (cmd === 'text') out(await call('/v4/group-channel/message/send', { fromUserId: 'jugaad_bot', toChannelIds: [a[0]], messageType: 'RC:TxtMsg', content: JSON.stringify({ content: a[1] }) }));
else console.log('unknown command');
