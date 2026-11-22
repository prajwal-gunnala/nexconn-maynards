# Reskilll submission — copy/paste

## 01 Project
**Project name:** Jugaad Street

**One-paragraph summary:**
Jugaad Street is a bulk group-buying marketplace for local communities, built on the Nexconn Chat SDK. Wholesale is 20–40% cheaper than retail, but it comes in quantities one household can't use: a whole fish, a 25 kg rice sack, a box of mangoes, a pest-control visit for the whole building. People nearby want the same things — they just have no simple way to find each other, agree on shares and pay without someone fronting the money. Jugaad Street turns that coordination into a product. Anyone — a society admin, a neighbour or a vendor — starts a "bucket": split one item into parts (one family takes the head of a fish, another the middle), unlock bulk price tiers as more people join, share a service across flats, or pool one trip to the wholesale market. People claim their share inside one live group chat, where every bucket is a live card that updates on every phone as others join. Payment is trust-free: with UPI, money is only held, never paid, until the bucket fills, and released automatically if it doesn't — or members simply book their share and meet at the market. A full bucket becomes one order and one delivery for the vendor, and each person collects with a private pickup OTP sent in chat. It's built for housing societies, offices, hostels and regular market-goers, and for the local vendors who get guaranteed, pre-committed demand instead of thirty separate deliveries.

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
