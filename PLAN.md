# Jugaad Street — product plan

**Team Maynards · Nexconn Build Challenge 2026 · deadline Nov 22, 23:59 AoE**

> A bulk-buying marketplace for local communities. **Anyone** (a society admin, a neighbour, a vendor) starts a
> **bucket**: a whole fish, a 100 kg rice order, a tower-wide pest-control booking, a trip to the fish market.
> Neighbours add their share inside the community chat. Members either **hold** money with UPI (taken only when the
> bucket fills, released if it doesn't) or **book and pay at the market**. A full bucket becomes an **order** with
> every member's details. Fish is the flagship example, from the team's own fish-market experience.

## 1. The problem

- A whole seer fish costs about **₹950/kg at the harbour**. Pre-cut seer steaks cost **₹1,400–3,700/kg**
  online, yet no one household can use a 5 kg fish.
- Neighbours want **different parts**: a Bengali family wants the head for *muri ghonto*, a Kerala family wants
  steaks for curry, and someone else wants the tail for fry. Today this is coordinated on WhatsApp: "who took
  what?", one person pays the vendor upfront and chases everyone, and nobody knows whether the deal is still on.
- Group-buying apps (Pinduoduo, DealShare, Citymall) pool **identical units**. Splitting **one item into different
  parts** isn't served by anyone. Splitwise and GPay split a bill only after one person has already paid.

## 2. The product

| Who | What they do |
|---|---|
| **Neighbour** | Sees pools in the society chat, taps a cut on a live diagram, reserves money with UPI, collects at the gate with an OTP |
| **Pool captain** (a society volunteer) | Starts or approves pools, nudges people when a cut is left over, earns a small discount |
| **Vendor** (fishmonger, mango farmer, rice trader, service provider) | Posts the morning catch or lot, gets a cut sheet once the pool fills, delivers to one gate, gets paid on handover |

### The core loop
1. **Post**: the vendor posts a lot ("Seer · 5.2 kg · ₹950/kg · cutoff 8:30 am") and chooses a split template.
2. **Card**: a live **share card** appears in the society group chat, sent by our server through Nexconn.
3. **Claim**: neighbours tap a cut, choose how it should be cut (curry, fry slices, steaks), and **reserve** the
   money in a UPI sheet. Every claim updates the card for everyone in real time through Nexconn message metadata.
4. **Lock**: when 100% is claimed, the pool locks. Holds are **captured**, the vendor gets a cut sheet, and the
   claimers move to a pool chat to agree the pickup time.
5. **Release**: if the pool doesn't fill by the cutoff, every hold is **released automatically** and nobody pays.
6. **Handover**: each buyer shows an OTP at the gate. The vendor enters it and the payout is released to the vendor.

### What makes it different
- **The share map**: a tappable picture of the actual item (fish cuts, a mango crate grid, a rice-sack bar). No other group-buying app does this.
- **Hold, don't pay**: modelled on NPCI's *UPI Reserve Pay* (block and debit, like an IPO application). It fixes the
  trust problem: nobody fronts money, and the app never holds a wallet balance (Otipy shut in 2025 with customer balances stuck).
- **Smart nudges**: when a cut is still open 30 minutes before the cutoff, the bot pings neighbours who took that
  cut before ("Ravi, the head is still open — you took it last time"), or the captain can take the remainder.
- **Chat is the marketplace**: the deal lives in the conversation people already have, so every action is a message.

### Split templates
| Template | Example | Shares |
|---|---|---|
| `fish` | Seer, rohu, tuna, hilsa | head · steaks 1–n · tail, priced by part |
| `crate` | Alphonso mango peti (6 dozen) | dozen-grid |
| `sack` | 25 kg basmati, 15 L oil tin | kg slices |
| `service` | Society pest control or tank cleaning (volume price) | flats; price drops as more join |

## 3. How it uses Nexconn (judges verify this)

| Nexconn feature | Where it is used |
|---|---|
| Chat UI kit (`ai_nexconn_chatui_plugin`) | channel list, chat screens, voice notes and images from vendors |
| Group channels (server API) | one **Street** group per society, one **pool** group per filled pool |
| Direct channels | neighbour ↔ vendor questions |
| Custom messages `js:pool` `js:claim` `js:lock` `js:otp` | share card, claim receipts, lock and payout cards, pickup OTP card |
| Message **metadata** (server-sent, `hasMetadata`) | the share card updates live on every claim, lock or release |
| Server REST bot `jugaad_bot` | system events, nudges, cutoff reminders |
| Tokens (`/v4/auth/access-token/issue`) | issued by our server; the App Secret never ships in the app |
| Mentions | the captain @-mentions people in nudges |

## 4. Architecture

```
Flutter app (Android)  ──REST──▶  server/ (Node, Express, JSON store)  ──signed REST──▶  Nexconn API (SG)
      │                                 │  issue tokens, create groups, send cards,
      └──── Nexconn Chat SDK ◀──────────┘  update card metadata, simulate the UPI reserve
```

- `app/`: Flutter 3.47, Android first (Nexconn's Flutter SDK has no web support). Provider for state,
  `google_fonts` (Baloo 2 + Inter), `flutter_svg`, `lottie`.
- `server/`: Node 22 with no native dependencies, so it runs locally (`adb reverse`) and on any free host.
  The App Key, App Secret and Access Key are read from `.env`, which is gitignored.
- Payments: a sandboxed **UPI Reserve** flow. A reserve sheet, PIN pad, hold, capture and release run
  as a state machine on the server. It is labelled *Demo payments* in the app. The production route is
  Razorpay/Cashfree UPI Reserve Pay plus Razorpay Route (`on_hold` settlement to the vendor).

## 5. Design
- **Licious-style layout** (photo-led product cards, category grid, Net wt · Pieces · Serves, sticky bottom bar) in our
  own brand: brick-tomato `#E4572E`, tint `#FFF1EC`, ink `#1F1A17`, savings green, held amber. Font **Plus Jakarta Sans**.
  Full tokens in `docs/CONTRACT.md`; screen flow in `docs/design/app-flow.html`.
- Images: hand-built vector logo and share maps; illustrations and photos from Google Flow (its visible watermark
  is kept, as required) or free-licensed stock (Pexels or Unsplash); Lottie for small animations.

## 6. Schedule
| Day | Date | Goal |
|---|---|---|
| 1 | Nov 13 | Plan. Spike: token, group, server-sent card, live metadata update rendered in Flutter |
| 2–3 | Nov 14–15 | Onboarding and login, society home, vendor posts a pool, share map, claim, UPI reserve, live card, pool chat |
| 4 | Nov 16 | Lock, capture, cut sheet, OTP handover, auto-release, wallet and savings, nudges, other templates |
| 5 | Nov 17 | Polish: logo, Flow images, animations, empty and error states, demo data |
| 6 | Nov 18 | Gemini + ChatGPT design review of every screen, fixes, testers in real societies (traction) |
| 7–8 | Nov 19–20 | **Under-60-second pitch film** in Remotion (problem → solution → unique → how it's built), animated, Gemini "Charon" voice |
| 9 | Nov 21 | Write-up PDF (with the App Key), submission, buffer |

## 7. Submission checklist
- [ ] Write-up PDF: problem, solution, Nexconn features used, **App Key `tdrvipkstz0f5`**
- [ ] Demo video (public YouTube or Drive link)
- [ ] Runnable app: APK + reachable server (**publishing only after the user says so**; everything is local until then)
- [ ] Public GitHub repo (root URL), with no secrets in its history
- [ ] Traction: active users on the Nexconn app, testers' feedback, screenshots
