# Jugaad Street — build contract

Every agent builds against this file. **Only the lead edits it.** If a contract change is needed, say so
in your report rather than diverging.

## Repo layout
```
app/        Flutter app (Android). package `jugaad_street`, applicationId `in.maynards.jugaadstreet`
server/     Node 22 local API + Nexconn REST client. Port 8787. ESM, Express 4, JSON file store
docs/       CONTRACT.md (this), design/ (boards, references), API examples
media/      source art (Flow downloads, logo sources); app-ready copies live in app/assets/
.env        repo root, gitignored: NEXCONN_APP_KEY, NEXCONN_APP_SECRET, NEXCONN_ACCESS_KEY(_NAME)
```
- Nothing is published (no git push, no deploy). Commits are local only.
- The app reaches the server through `adb reverse tcp:8787 tcp:8787` → `http://localhost:8787`.
- Nexconn region: **Singapore**. API base `https://api.sg-light-api.com` (backup `api-b.sg-light-api.com`); Flutter `AreaCode.sg`.

## Domain words (use these in UI and code)
| Word | Meaning |
|---|---|
| Community | a society, street, office or hostel; has one **Street** chat (Nexconn group `street_<communityId>`) |
| Bucket | a group buy anyone can start. Types: `split`, `bulk`, `service`, `trip` |
| Share | one member's part of a bucket (cuts, kg, a flat, items on a list) |
| Hold | money blocked with UPI (sandbox), captured when the bucket fills, released if it doesn't |
| Order | created when a bucket fills; one line per member with their details |
| Admin | community admin (approves vendors, nudges); Vendor = seller |

Settle modes: `hold` (UPI hold now) or `at_market` (book only; pay when you meet at the market or at pickup).

## REST API (JSON; `Authorization: Bearer <sessionToken>` except auth routes)
All money is integer rupees. Times are ISO strings. Errors: `{ "error": { "code": "...", "message": "human text" } }` with 4xx/5xx.

### Auth
- `POST /api/auth/otp` `{phone}` → `{ok:true, devCode:"1234"}` (demo: code is always 1234)
- `POST /api/auth/verify` `{phone, code, name?}` → `{sessionToken, user, nexconn:{appKey, token, userId}}`
  Seeded phones log in as seeded people (see Seed). A new phone needs `name`.
- `GET /api/me` → `{user, memberships:[{community, unit, role}]}`

### Communities
- `GET /api/communities?q=` → `[Community]`
- `POST /api/communities/:id/join` `{unit}` → `{membership}` (server adds the user to the Nexconn Street group)
- `GET /api/communities/:id` → `Community` with `stats:{members, savedThisMonth, liveBuckets}`

### Buckets
- `GET /api/communities/:id/buckets?category=&type=&status=live` → `[Bucket]`
- `GET /api/buckets/:id` → `Bucket` (includes `myShare` for the caller, `shares` summary list)
- `POST /api/buckets` `BucketDraft` → `Bucket` (server posts the live card into the Street chat)
- `POST /api/buckets/:id/shares` `{unitIds?|qty?|items?, options?, payMode}` → `{share, bucket}`
  - `payMode:"hold"` → share `status:"pending_payment"` with `hold:{id, amount, status:"created"}`
  - `payMode:"at_market"` → share `status:"booked"`
- `POST /api/holds/:id/authorize` `{vpa, pin}` → `{share, bucket}` (any 4–6 digit pin succeeds; `0000` fails with `PIN_INCORRECT`)
- `DELETE /api/shares/:id` → releases the hold, frees units → `{bucket}`
- `POST /api/buckets/:id/close` → demo control: runs the cutoff now (fill → order, else expire + release)
- `POST /api/shares/:id/checkin` → market-day "I'm here"

### Orders, wallet, vendor, admin
- `GET /api/orders/:id`, `GET /api/me/orders` → `Order`, `[Order]`
- `POST /api/orders/:id/handover` `{otp}` → `{order}` (vendor enters a member's OTP; that line becomes `collected`)
- `GET /api/me/wallet` → `{heldNow, paidThisMonth, releasedThisMonth, savedTotal, savedThisMonth, entries:[WalletEntry]}`
- `GET /api/vendor/dashboard` → `{vendor, heldDemand, buckets:[Bucket], packing:[{communityName, lines:[OrderLine]}]}`
- `GET /api/admin/communities/:id` → `{savedThisMonth, members, pendingVendors:[...], nudges:[{bucketId, text}]}`
- `POST /api/admin/nudge` `{bucketId}` → bot posts a nudge in the Street chat
- `GET /api/health` → `{ok, nexconn:"ok"|"error"}`

### Shapes
```jsonc
// Bucket
{ "id":"b_seer", "communityId":"c_seabreeze", "type":"split", "category":"fish",
  "title":"Whole Seer (Vanjaram)", "subtitle":"Landed 6:10 am at Kasimedu", "image":"seer",
  "vendor":{"id":"v_murugan","name":"Murugan Fish Stall","place":"Kasimedu Harbour","rating":4.8},
  "createdBy":{"id":"u_ravi","name":"Ravi","unit":"C-801"},
  "settleMode":"hold", "meet":null, "cutoffAt":"…", "deliverAt":"…", "pickupPoint":"Gate 2",
  "unitLabel":"cut", "retailUnitPrice":1400, "netWeight":"5.2 kg", "serves":"8 families",
  "units":[{"id":"head","label":"Head","grams":600,"price":420,"owner":{"id":"u_s","name":"Sunita","unit":"A-201"}|null}],
  "tiers":[{"minQty":25,"unitPrice":96},{"minQty":100,"unitPrice":88}],   // bulk & service
  "items":[{"id":"onion","name":"Onion","unit":"kg","price":28,"qty":10,"members":3}], // trip
  "capacity":300,                                                         // trip, kg
  "progress":{"filled":6,"target":8,"members":6,"held":3920,"unitPrice":950,
              "nextTier":{"minQty":100,"unitPrice":88,"remaining":18}|null,"percent":75},
  "status":"live",  // live | ordered | market_day | delivering | completed | expired | cancelled
  "cardMessageId":"…", "myShare":Share|null }
// Share
{ "id":"s_1","bucketId":"b_seer","user":{"id":"u_ananya","name":"Ananya","unit":"B-1204"},
  "qty":1,"unitIds":["s2"],"items":null,"options":{"cut":"Curry"},"payMode":"hold",
  "estAmount":700,"finalAmount":null,
  "status":"pending_payment|held|booked|captured|released|checked_in|collected|left",
  "hold":{"id":"h_1","amount":700,"status":"created|held|captured|released","vpa":"ananya@okaxis"}|null,
  "otp":"5193"|null }
// Order
{ "id":"JS-2041","bucketId":"…","title":"…","total":9152,"heldTotal":7920,"atPickupTotal":1232,
  "status":"created|sent|packed|delivered","createdAt":"…",
  "lines":[{"userId":"…","name":"Ananya","unit":"B-1204","qty":10,"qtyLabel":"10 kg","amount":880,
            "payMode":"hold","paymentStatus":"captured","otp":"5193","collected":false}] }
```

## Nexconn chat contract
- Bot user: `jugaad_bot`, name **Jugaad Street**. Vendors are real Nexconn users too (seeded).
- Groups: `street_<communityId>` (all members), `bucket_<bucketId>` (members + vendor, created when a bucket becomes an order).
- Custom message types (register in the app **after init, before connect**, flag `counted`):

| Type | Sent by | Content fields (all string values) | Metadata (live) |
|---|---|---|---|
| `js:bucket` | server, Street group, `hasMetadata:true` | `bucketId,type,title,subtitle,image,vendor,cutoffAt,unitLabel` | `p` = JSON progress, `s` = status, `u` = JSON `[[unitId, ownerInitial|""],…]` (split only) |
| `js:event` | server, Street or bucket group | `bucketId,kind(joined/left/locked/expired/nudge/checkin),text,actor` | — |
| `js:order` | server, bucket group | `orderId,bucketId,title,total,members` | — |
| `js:otp` | server, direct bot → member | `orderId,otp,pickupPoint,window` | — |

- Every share change → server sets metadata on the bucket's card (`/v4/channel-type/message/metadata/set`, channelType 3) and posts a `js:event`.
- The app renders these with `customMessageBubbleBuilders` in the Chat UI kit; tapping a `js:bucket` card opens the bucket screen.

## Design tokens (app)
Licious-style layout (photo-led cards, category grid, Net wt · Pieces · Serves line, sticky bottom bar) in our own brand.

| Token | Value | Use |
|---|---|---|
| `brand` | `#E4572E` | primary buttons, active tab, progress |
| `brandDeep` | `#B93A17` | pressed, text on tint |
| `brandTint` | `#FFF1EC` | chips, banners, selected backgrounds |
| `ink` | `#1F1A17` | text |
| `inkMuted` | `#6E6660` | secondary text |
| `line` | `#EFE9E5` | dividers, card borders |
| `surface` | `#FFFFFF` | cards and pages |
| `canvas` | `#FAF7F5` | page background behind cards |
| `save` | `#12A150` | savings, success, captured |
| `held` | `#B7791F` on `#FFF6E0` | held money |
| `released` | `#5B6472` on `#EEF0F3` | released money |

- Font: **Plus Jakarta Sans** (google_fonts) — 800 for big numbers/titles, 700 for headings, 500/600 for UI.
- Spacing scale 4 / 8 / 12 / 16 / 20 / 24 / 32. Page gutter 16. Card radius 16, sheet radius 24, chip radius 999.
- Cards: white, 1px `line` border, no heavy shadows; product photos fill the top of the card with radius 12.
- Money: `₹1,320` (Indian grouping), strike-through retail price in `inkMuted`, savings in `save`.

## Seed (server creates on first run)
Community **Sea Breeze Towers** (`c_seabreeze`, OMR Chennai, 412 flats) + **Palm Grove Apartments** (`c_palmgrove`).
People (phone → user): Ananya B-1204 `9000000001` (demo hero), Ravi C-801 `…02`, Meera A-303 `…03`, Kiran B-402 `…04`,
Priya A-1101 `…05` (admin), Arjun B-702 `…06`, Sunita A-201 `…07`.
Vendors: Murugan Fish Stall (Kasimedu) `…11`, Sri Balaji Traders (Koyambedu) `…12`, SafeHome Pest Services `…13`,
Devgad Mango FPO `…14`, Al-Noor Meats `…15`.
Buckets: seer split (8 cuts, 6 claimed), basmati bulk (tiers 25→₹96, 100→₹88; 82 kg filled), pest control service
(tiers 10→₹480, 25→₹400, 50→₹340; 31 flats), Koyambedu trip (capacity 300 kg, 186 booked), Alphonso bulk (dozens),
Bakrid goat split (7 shares, `hold`), Kasimedu book-and-meet (2 halves, `at_market`, meet Gate 3 Sun 6:00).

## Additions from the server build (all compatible with the above)
- Rules: a hold is quoted at the tier reached including the member's own quantity, and the amount captured is never more
  than the amount held. `payMode` must match the bucket's `settleMode` (`PAY_MODE_NOT_ALLOWED`). A split bucket, or a full
  trip or lot, locks the moment its last part is paid; bulk and service buckets go ahead at the cutoff if the first tier is
  reached; a trip goes ahead at the cutoff once `minLoadKg` is reached. Unpaid `pending_payment` shares are released after 15 min.
- Bucket adds `description, unitPrice, minQty, maxQty, lotQty, maxUnitsPerMember, optionGroups:[{key,label,choices}],
  minLoadKg, transportFee, orderId, closedAt`; `progress` adds `goAt`, and `transportPerKg` for trips. `units` is null
  except on split buckets, `items` null except on trips.
- Share adds `qtyLabel, orderId, savings`. Order adds `communityId, vendorId, image, pickupPoint, window, myLine`. Lines add
  `shareId, options, savings`, and `transport` on trips. Members only see their own OTP. `at_market` lines go `due` → `paid`.
- WalletEntry: `{id, shareId, bucketId, title, image, orderId, kind:"held"|"paid"|"released"|"at_market", amount, savings, at}`.
- Image keys: `seer basmati pest koyambedu alphonso goat paarai prawns banana crab`; communities `seabreeze palmgrove`.
- Street group id is `community.streetGroupId`. `js:event` kinds: `joined left locked expired nudge checkin`.
- Error codes: see `server/README.md`.
- Demo: re-seed just before recording (`npm run seed` with the API stopped); cutoffs are relative to seed time.
