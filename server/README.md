# Jugaad Street API (`server/`)

Node 22 · ESM · Express 4 · JSON file store · no native modules. Implements `docs/CONTRACT.md`.

## Run

```bash
cd server
npm install
npm run dev      # node --watch, port 8787
npm start        # same, without watch
npm test         # node:test: domain, flows, HTTP and the Nexconn client (Nexconn mocked)
npm run seed     # reset server/data/db.json to the demo seed and push it into Nexconn
npm run smoke    # boots the API against real Nexconn on a copy of the DB, Ananya joins basmati with 10 kg
```

- Reads `NEXCONN_APP_KEY` / `NEXCONN_APP_SECRET` from the repo-root `.env`. Secrets and tokens are never logged.
- `PORT` (default 8787), `JUGAAD_DB` (default `server/data/db.json`), `NEXCONN_DISABLED=1` (run offline).
- First boot with an empty store seeds automatically. **Stop the API before `npm run seed`** (or restart it after):
  a running server keeps its own copy in memory and would overwrite the new seed on its next write.
- Phone: `adb reverse tcp:8787 tcp:8787`, then the app uses `http://localhost:8787`.
- If Nexconn is unreachable the API keeps working; chat side effects are skipped with a one-line warning and
  `GET /api/health` reports `"nexconn":"error"`.

## Demo logins (OTP is always `1234`)

| Phone | Who |
|---|---|
| 9000000001 | Ananya B-1204 (demo hero; holds 1 flat of pest control) |
| 9000000002–07 | Ravi C-801, Meera A-303, Kiran B-402, Priya A-1101 (**admin**), Arjun B-702, Sunita A-201 |
| 9000000011–15 | vendors: Murugan Fish Stall, Sri Balaji Traders, SafeHome Pest, Devgad Mango FPO, Al-Noor Meats |

A new phone + `name` creates an account (then `POST /api/communities/:id/join {unit}`).

## Seed (times relative to "now", IST)

| Bucket | Type | State |
|---|---|---|
| `b_seer` Whole Seer | split, 8 cuts | 6 held; Steak 2 and Tail open; cutoff now+3 h |
| `b_basmati` Aged Basmati | bulk kg, 25→₹96, 100→₹88 | 82 kg; cutoff 8 pm |
| `b_pest` Pest Control | service, 10→₹480, 25→₹400, 50→₹340 | 31 flats; Sunday 6 pm |
| `b_trip` Koyambedu Saturday Run | trip, 300 kg, ₹1,800 tempo | 186 kg; Saturday 5 am |
| `b_alphonso` Devgad Alphonso | bulk dozen, 12→₹1,150, 24→₹990 | 16 dozen; now+26 h |
| `b_goat` Whole Goat | split, 7 shares | 5 held; Saturday 9 pm |
| `b_paarai` Kasimedu Book & Meet | split, 2 halves, `at_market` | Ravi booked the head half; meet Gate 3, Sunday 6:00 |
| `b_past_*` | prawns (completed), bananas (completed, October), crabs (expired) | Ananya's wallet history |

Seeding calls Nexconn: issues tokens for every user + `jugaad_bot`, creates (or joins) `street_c_seabreeze` and
`street_c_palmgrove`, posts one `js:bucket` card per live bucket (stores `cardMessageId`) and a few chat lines.
Re-seeding posts fresh cards and marks the previous live cards `s:"cancelled"`.

## Endpoints

All JSON. `Authorization: Bearer <sessionToken>` except auth and health. Errors: `{error:{code,message}}`.

| Method | Path | Notes |
|---|---|---|
| GET | `/api/health` | `{ok, nexconn:"ok"\|"error", nexconnDetail}` (live probe, cached 60 s) |
| POST | `/api/auth/otp` | `{phone}` → `{ok, devCode:"1234"}` |
| POST | `/api/auth/verify` | `{phone, code, name?}` → `{sessionToken, user, nexconn:{appKey, token, userId}}` |
| GET | `/api/me` · `/api/me/orders` · `/api/me/wallet` | |
| GET | `/api/communities?q=` · `/api/communities/:id` | Community + `stats` |
| POST | `/api/communities/:id/join` | `{unit}`; adds you to the Street group |
| GET | `/api/communities/:id/buckets?category=&type=&status=` | `status` omitted or `all` = every status |
| POST | `/api/buckets` | BucketDraft → Bucket; posts the card |
| GET | `/api/buckets/:id` | includes `myShare`, `shares` |
| POST | `/api/buckets/:id/shares` | `{unitIds}` (split) · `{qty}` (bulk/service) · `{items:[{id,qty}]}` (trip), `options`, `payMode` |
| POST | `/api/holds/:id/authorize` | `{vpa, pin}`; pin `0000` → `PIN_INCORRECT` |
| DELETE | `/api/shares/:id` | leave; releases the hold |
| POST | `/api/shares/:id/checkin` | after the bucket is confirmed |
| GET | `/api/orders/:id` | members see only their own OTP (`myLine`) |
| POST | `/api/orders/:id/handover` | `{otp}`; vendor, bucket creator or admin |
| GET | `/api/vendor/dashboard` | log in as a vendor phone |
| GET | `/api/admin/communities/:id` · POST `/api/admin/nudge {bucketId}` | Priya (admin) |

### Demo controls

- `POST /api/buckets/:id/close` runs the cutoff now: filled (split) / first tier or minimum load reached
  (bulk, service, trip) → order + captures + OTP DMs + bucket group; otherwise expire + release every hold.
- A split or a full trip/lot locks **immediately** when the last part is paid.
- The scheduler runs every 30 s: due cutoffs, and unpaid (`pending_payment`) claims older than 15 min are released.
- One share per member per bucket. Good demo paths:
  - **Tier unlock**: Ananya takes 18 kg of basmati (82 → 100 kg unlocks ₹88; her own hold is already at ₹88) →
    `close` → the six earlier members, held at ₹96, are captured at ₹88.
  - **Instant lock**: Ananya takes the paarai tail half (`at_market`) → order, status `market_day`.
  - **Split lock**: goat has `hr` and `offal` open; Ananya + Meera (or Priya/Arjun/Sunita) take them → order + OTPs.
  - **Seer**: everyone seeded except Ananya already has a cut, so the Tail needs a new phone (or let it expire via `close`).

## Money rules

- Hold = estimated amount at the moment you join (bulk/service at the tier reached including your qty; trip goods +
  transport by weight against max(load, minimum load)). Capture at order time uses the final tier / final load and
  **never exceeds the hold** (if people left and the tier dropped, you still pay at most what you reserved).
- `at_market` shares: no hold, `status:"booked"`, order line `payMode:"at_market"`, `paymentStatus:"due"` → `"paid"` on handover.
- Savings = retail (`retailUnitPrice` × kg/qty, or item `retailPrice`) − final amount.

## Nexconn messages (what the app renders)

All content values are strings. Cards and events are sent by `jugaad_bot`.

- `js:bucket` (Street group, `hasMetadata`): content `bucketId,type,title,subtitle,image,vendor(name),cutoffAt,unitLabel`.
  Metadata: `p` = progress JSON (`filled,target,members,held,unitPrice,nextTier,percent,goAt`, trip adds `transportPerKg`),
  `s` = bucket status, `u` (split only) = `[["head","S"],["s2",""],…]`.
- `js:event`: `bucketId, kind, text, actor` (actor = userId or `jugaad_bot`). Kinds: `joined`, `left`, `locked`,
  `expired`, `nudge` (Street group), `checkin` and a welcome `locked` (bucket group).
- `js:order` (bucket group `bucket_<bucketId>`): `orderId,bucketId,title,total,members`.
- `js:otp` (direct, bot → member): `orderId,otp,pickupPoint,window`.

## Layout

```
src/index.js       boot + 30 s scheduler        src/app.js      routes, CORS, request log, errors
src/service.js     use cases + Nexconn queue    src/store.js    JSON store (temp file + rename)
src/nexconn.js     signed client, backup host   src/seed.js     seed data + Nexconn push
src/domain/        pricing, claims, holds, cutoff, wallet (pure, unit-tested)
```
