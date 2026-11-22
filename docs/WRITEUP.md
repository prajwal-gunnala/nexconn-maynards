# Jugaad Street

**Wholesale prices for your whole street.**
Team Maynards · Nexconn Build Challenge 2026 · Track: Marketplace & Support (Open Innovation fit)
**Nexconn App Key: `tdrvipkstz0f5`** (Singapore data centre)

---

## Why we built it

Every Sunday morning we're at the Kasimedu fish market. The best catch is the big fish: a whole vanjaram (seer),
about ₹950/kg at the harbour. But big fish are sold only whole, and five kilos is too much for one family, so we
walk away with a smaller fish. Right there, another family wanted just the head for curry, and someone from across the
city wanted the middle for fry. Together we could have bought that whole fish. We just didn't know each other.

The same thing happens everywhere in an Indian housing society: a 25 kg rice sack, a peti of Alphonso mangoes, a
Bakrid goat share, pest control for the whole tower. Wholesale is 20–40% cheaper, but only in quantities one
household can't use. Societies already try to buy together on WhatsApp. It turns into "who wants how much?", one
person fronting the money and chasing everyone, no idea whether the order is on, and a vendor making 30 separate
deliveries.

## What it is

Jugaad Street is a bulk-buying marketplace that lives inside the community's chat.

- **Anyone starts a bucket**: a society admin, a neighbour or a vendor. Four kinds:
  - **Split**: one big item, different parts. A whole fish split into head, six steaks and tail; a goat in 7 shares.
  - **Bulk**: price tiers unlock as the group grows. Basmati at ₹96/kg from 25 kg, ₹88/kg from 100 kg.
  - **Service**: the per-flat price drops as more flats join. Pest control ₹480 → ₹400 → ₹340.
  - **Market trip**: one run to the Koyambedu wholesale market, everyone's list, transport split by weight.
- **Neighbours claim their share inside the society chat.** Every bucket is a live card in the Street group chat;
  each claim updates the card on every phone in about a second.
- **Money is held, never paid, until the bucket fills.** Modelled on NPCI's UPI Reserve Pay (block-and-debit, like
  an IPO application). If the bucket doesn't fill by the cutoff, every hold is released automatically. With price
  tiers you hold at today's price and pay the lower price the group unlocked.
- **Or simply book your half and meet at the market.** For fish runs, members book a share without paying and buy
  together at the stall at a set time.
- **A full bucket becomes one order**: every member's flat, share, amount and payment state, sent to the vendor as
  one packing list, one delivery to the gate, each member collecting with a 4-digit OTP.

## What's unique

1. **Splitting one item into different parts.** Group-buying apps (Pinduoduo, DealShare, Citymall) pool identical
   units. No one lets neighbours split one fish where one family wants the head for *muri ghonto* and another wants
   steaks for curry. Our tappable share map does.
2. **Hold, don't pay.** Nobody fronts money and the app never keeps a wallet balance (Otipy shut in 2025 with
   customer balances stuck). Trust comes from the payment rail, not from a person.
3. **Chat is the marketplace.** The deal lives where neighbours already talk. Every claim, nudge, lock and pickup
   code is a message.
4. **Book-and-meet.** Not everything needs prepayment. A fish-market meet-up is a booking, a time and a place.

## How it uses Nexconn

| Nexconn feature | Where |
|---|---|
| **Chat UI kit for Flutter** (`ai_nexconn_chatui_plugin` 26.2.11) | Chats tab, Street group chat, bucket group chats, vendor direct chats, voice notes and images |
| **Group channels** (server API `group-channel/create`, `join`) | One **Street** group per community; one group per filled bucket (buyers + vendor) |
| **Direct channels** (`direct-channel/message/send`) | Private pickup OTP from the bot to each member; neighbour ↔ vendor chats |
| **Custom messages** `js:bucket`, `js:event`, `js:order`, `js:otp` | Rendered as rich cards with `customMessageBubbleBuilders` |
| **Message metadata** (`hasMetadata`, `channel-type/message/metadata/set`, `onMessageMetadataUpdated`) | The live bucket card: progress, price tier, owners of each cut update on every phone |
| **Server-sent bot messages** | `jugaad_bot` posts new buckets, claims, nudges, lock and expiry events |
| **Access tokens** (`auth/access-token/issue`) | Issued by our server per user; the App Secret never ships in the app |
| **Call SDK for Android** (`ai.nexconn.chat:call` 26.2.0, via a Flutter platform channel) | Call buttons in direct chats (1-to-1) and bucket / Street groups (group calls), voice and video; runs on the same Nexconn connection as chat (calls need the audio/video service enabled for the App Key in the Nexconn console) |

**Features built on Nexconn:** the live bucket card, claim and release events, the bucket order chat, private
pickup codes, admin nudges with mentions, vendor chats, and calls (1-to-1 and group) from any chat header.

## How it's built

- **App:** Flutter (Android), Licious-style UI, Plus Jakarta Sans, product photography generated with Google Flow.
  Screens: onboarding and OTP login, community join, Street home (banners, categories, closing-soon rail), buckets,
  bucket detail for all four types (fish share map, tier ladder, price-drop chart, market-trip list, meet-at-market
  card), UPI hold sheet with PIN pad, create bucket in three taps from templates, orders with pickup OTP, wallet with
  savings, vendor packing list and OTP handover, admin nudges, and the Nexconn chats.
- **Server:** Node 22 + Express: OTP login, Nexconn token issue, bucket rules (pricing tiers, split claims, trip
  transport split by weight), UPI-hold sandbox state machine (held → captured or released), cutoff scheduler that
  turns full buckets into orders with OTPs, Nexconn bot and live-card updates. 19 automated tests.
- **Payments:** a sandbox of the UPI Reserve flow. Production route: Razorpay or Cashfree UPI Reserve Pay
  (merchant category grocery/food is allowed) plus Razorpay Route with settlement `on_hold` until OTP handover.

## How we scale

1. **Every bucket recruits its own users.** A bucket only completes when enough people join, so whoever starts one
   shares it — in the society, at the stall, with family across the city. Growth is built into the product.
2. **Vendors bring their crowd.** A fish seller with a big catch starts a bucket before the boat unloads and sells
   the whole fish early. One market association brings many stalls.
3. **Local captains.** One trusted person per society, office, college or hostel runs buckets and earns a small
   share — the community-leader model India's group-buying apps already use to enter new areas.
4. **Market by market, city by city.** Start with one market on one day (Kasimedu, Sundays), then copy the playbook to
   each city's fish harbours, vegetable markets and grain markets: about ten captains per market.
5. **More categories on the same rails.** Fish → meat shares → rice and staples → seasonal fruit → festival buying →
   home services (pest control, AC servicing) → big-ticket items (solar panels or water purifiers for a whole
   building). Same bucket, same chat, same UPI hold, all year round.
6. **Further out.** "Boat to bucket": fishermen sell the morning catch in shares before landing. "Farm to street": a
   farmer's mango truck fills buckets before it leaves the farm. Vendors who can't type sell by voice note in Tamil or
   Hindi in the same Nexconn chat. Vendors see demand before buying stock, so less unsold fish and fewer delivery trips.
7. **The technology already scales.** Nexconn runs the chat, groups and live updates, so we run no chat servers; the
   UPI hold moves to Razorpay or Cashfree UPI Reserve Pay; each bucket is one delivery with OTP handover.

**The moat:** a weekly habit and the network of people who go to the same market — hard for a big e-commerce app to copy.

## Business model and growth

- 2–4% fee from vendors on completed orders, part of it shared with the community admin who runs buckets.
- Vendors get guaranteed, pre-held demand and one drop-off point instead of 30 deliveries.
- Paid tools for vendors: featured buckets across societies and demand forecasts.
- Growth is society by society: one admin brings a whole tower; each bucket card is an invite link.
- Year-round categories: weekly fish and vegetables, monthly staples, mango season, Bakrid shares, Durga Puja
  hilsa, Diwali dry fruits, pre-summer AC servicing.

## Built during the challenge

Everything in this repository was built during the challenge (Nov 2026): the product, server, Flutter app,
Nexconn integration, images and film. Nothing existed before.

## Traction

No public traction numbers yet: the app was built and tested during the challenge week.

## Links

- Demo video: https://youtu.be/b_FC3qWJCMM
- Try it in the browser + download: https://prajwal-gunnala.github.io/nexconn-maynards/
- App download (APK): https://github.com/prajwal-gunnala/nexconn-maynards/releases/tag/v1.0
- Source: https://github.com/prajwal-gunnala/nexconn-maynards
- Demo logins (OTP 1234): Ananya 9000000001 (member), Priya 9000000005 (admin), Sri Balaji 9000000012 (vendor)
