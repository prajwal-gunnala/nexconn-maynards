# Reskilll submission — copy/paste

## 01 Project
**Project name:** Jugaad Street

**One-paragraph summary:**
Jugaad Street is a bulk group-buying marketplace for local communities, built on Nexconn. Big things are cheaper
together — a whole fish at the harbour, a 25 kg rice sack, a box of mangoes, pest control for the whole building — but
they come in quantities one family can't use: a five-kilo vanjaram at the Kasimedu fish market is sold only whole. The
neighbour who wanted the head for curry and the person from across the city who wanted the middle for fry were at the
same stall; they just didn't know each other. In Jugaad Street anyone (a society admin, a neighbour or a vendor) starts
a "bucket": split one big item into parts, unlock bulk price tiers as more people join, share a service, or run one trip
to the wholesale market. Neighbours — or anyone heading to the same market — claim their share inside one live Nexconn
group chat, where every bucket is a live card that updates on every phone in about a second. With UPI, money is only
held, never paid, until the bucket fills (released automatically if it doesn't), or you simply book your half and meet
at the market. A full bucket becomes one order and one delivery; each person collects with a private pickup OTP sent
in chat, and the vendor hands over by OTP. It's for housing societies, regular market-goers and the local vendors who
sell to them.

## 02 Proof of Nexconn integration
**Packages:** Chat SDK ✔ · Chat UI ✔ · Call SDK (✔ only if the call agent's integration is verified)

**App Key:** tdrvipkstz0f5

**SDK features you used:**
- Chat SDK + Chat UI kit (`ai_nexconn_chat_plugin` / `ai_nexconn_chatui_plugin` 26.2.11, Flutter Android): the Chats
  tab, the Street group chat, bucket group chats and vendor direct chats, with message history, images and voice notes.
- Group channels (server API group-channel/create, join, dismiss): one Street group per community and one group per
  filled bucket (buyers + vendor).
- Direct channels (direct-channel/message/send): private pickup OTPs from the Jugaad Street bot; neighbour ↔ vendor chat.
- Custom messages js:bucket, js:event, js:order, js:otp rendered as rich cards with customMessageBubbleBuilders.
- Message metadata (hasMetadata, channel-type/message/metadata/set, onMessageMetadataUpdated): the live bucket card —
  progress, price-tier unlocks and who took which part update in place on every phone.
- Server-sent bot messages: new buckets, claims, nudges with mentions, lock/expiry events.
- Access tokens (auth/access-token/issue) issued per user by our server; the App Secret never ships in the app.
- (Call SDK — 1-to-1 calls from direct chats and group calls from bucket/Street groups — only if verified.)

## 03 Links
- **Live app or download:** https://prajwal-gunnala.github.io/nexconn-maynards/ (click-through demo + APK download)
  — or direct APK: https://github.com/prajwal-gunnala/nexconn-maynards/releases/latest/download/JugaadStreet.apk
- **GitHub:** https://github.com/prajwal-gunnala/nexconn-maynards
- **Demo video:** https://youtu.be/b_FC3qWJCMM  (set it to Unlisted before submitting)

## 04 Write-up
Upload `docs/Jugaad_Street_Writeup.pdf`.

## 05 Traction
Optional — leave empty unless there are real testers.

## 06 Prior work
No, built for this challenge.
