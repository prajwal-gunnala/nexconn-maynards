# Jugaad Street

**Bulk group-buying for your local community — built on the Nexconn Chat SDK.**

Big things are cheaper together: a whole fish at the harbour, a 25 kg rice sack, a peti of mangoes, pest control for
the whole building. But a five-kilo vanjaram is sold only whole, and it's too much for one family. The neighbour who
wanted the head for curry and the person across the city who wanted the middle for fry were at the same stall — they
just didn't know each other.

Jugaad Street lets anyone start a **bucket**. Neighbours, or anyone heading to the same market, claim their share
**inside one live Nexconn chat**. With UPI, money is only **held, never paid, until the bucket fills** — or you simply
**book your half and meet at the market**. A full bucket becomes one order, one delivery, and each person collects
with a pickup OTP.

- **Nexconn App Key:** `tdrvipkstz0f5` (Singapore data centre)
- **Demo video:** see the submission / `site/`
- **Try it (Android):** download the APK from [Releases](../../releases/latest) · demo logins, OTP `1234`:
  Ananya `9000000001` (member), Priya `9000000005` (admin), Sri Balaji `9000000012` (vendor)
- **Write-up:** [`docs/Jugaad_Street_Writeup.pdf`](docs/Jugaad_Street_Writeup.pdf)

## How Nexconn is used

| Nexconn feature | Where in the code | What it does in the app |
|---|---|---|
| **Chat SDK** `ai_nexconn_chat_plugin` 26.2.11 | `app/lib/core/nexconn/nexconn_service.dart`, `chat_session.dart` | Connect with server-issued access tokens, channels, history, live events |
| **Chat UI kit** `ai_nexconn_chatui_plugin` 26.2.11 (vendored in `app/third_party/`) | `app/lib/features/chat/` | Chats tab, Street group chat, bucket group chats, vendor direct chats, voice notes, images |
| **Group channels** (server API `group-channel/create`, `join`, `dismiss`) | `server/src/nexconn.js` | One Street group per community; one group per filled bucket (buyers + vendor) |
| **Direct channels** (`direct-channel/message/send`) | `server/src/nexconn.js` | Private pickup OTP from the bot; neighbour ↔ vendor chats |
| **Custom messages** `js:bucket`, `js:event`, `js:order`, `js:otp` | `app/lib/core/nexconn/js_messages.dart`, `app/lib/features/chat/js_bubbles.dart` | Rich bucket / event / order / OTP cards via `customMessageBubbleBuilders` |
| **Message metadata** (`channel-type/message/metadata/set`, `onMessageMetadataUpdated`) | `server/src/nexconn.js`, `nexconn_service.dart` | The **live bucket card**: progress, price tier and who took which part update on every phone in about a second |
| **Access tokens** (`auth/access-token/issue`) | `server/src/nexconn.js` | Issued per user by our server; the App Secret never ships in the app |

## Repository

```
app/      Flutter Android app (go_router, provider), golden-screenshot harness in app/test/golden/
server/   Node 22 + Express API: OTP login, Nexconn tokens + bot, bucket rules, UPI-hold sandbox, cutoff scheduler (19 tests)
site/     Static landing page (GitHub Pages): click-through phone prototype + APK download
docs/     Write-up, API contract, design notes, reviews
scripts/  Nexconn dev helper (tokens, groups, cards, metadata)
```

## Run it locally

1. Create `.env` in the repo root (never committed):
   ```
   NEXCONN_APP_KEY=tdrvipkstz0f5
   NEXCONN_APP_SECRET=<from console.nexconn.ai>
   ```
2. Server: `cd server && npm install && npm run seed && npm start` (port 8787). Tests: `npm test`.
3. App: `cd app && flutter pub get && flutter run --dart-define=API_BASE=http://localhost:8787`
   (on an emulator/device over USB: `adb reverse tcp:8787 tcp:8787`).

## Built during the challenge

Everything here was built for the Nexconn Build Challenge 2026 (November 2026) by Team Maynards: product, server,
app, Nexconn integration, images (Google Flow, watermarks kept) and film.
