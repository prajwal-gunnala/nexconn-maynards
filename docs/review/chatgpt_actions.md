# Design review 2: action list (ChatGPT)

Built from ChatGPT's two answers (raw text in `chatgpt_review.md`). This is the second review, after the fixes from `gemini_actions.md`. I checked each point against the sheets in `review2/`, the full-size PNGs and, where needed, the code (`lib/`, `server/src/service.js`).

- **Merged:** duplicate points, and points Gemini already raised.
- **Fixed:** points where ChatGPT misread the screen.
- **Added:** issues I found while checking. They are marked *(added)*.
- **Dropped:** advice that breaks product rules: no real payments, keep the Flow watermark, keep the group-buying home, no made-up certifications or brands.

ChatGPT's overall view: the group-buying home works ("do not move towards a catalogue"). The fish-cut picker, the price tiers and the live chat cards are the strongest parts. The biggest risk now is **data that disagrees between screens for the same order**, not the visual polish. My own check agrees. Several numbers, IDs, OTPs and times still differ between screens, including some that Gemini's X1 was meant to fix.

Most of these mismatches come from two sources. The golden fixtures (`test/golden/*_golden_test.dart`) each build their own data. The chat, vendor and admin shots in `app/docs/shots/` come from the live server seed. So the main fix is one seed that both use.

Priority key: **P0** do before the demo video, **P1** if time allows, **P2** nice to have. Effort: S is under 30 min, M is about 1–2 h.

## Top 10, in order

| # | Area | Action | Pri | Effort |
|---|------|--------|-----|--------|
| 1 | Cross-cutting | One seed for the basmati order JS-2043, used by goldens and the live server: same OTP, kg, ₹, order ID and neighbour count on every screen (X1) | P0 | M |
| 2 | Cross-cutting | Finish Gemini's X1: meet and pickup times and places still differ across screens (X2) | P0 | S–M |
| 3 | Chat | Clear the duplicated "Ananya (B-1204) took 10 kg" before recording. Reseed the Street channel so each join posts one event (CH1) | P0 | S |
| 4 | Orders + Vendor | One payout story: the buyer is charged at the final price when the bucket fills, and the vendor gets it at the OTP handover. Change "Paid to vendor" (R1) | P0 | S |
| 5 | Create | Pay-at-market step still says "every hold is released". Make the cutoff copy depend on the pay mode (C1) | P0 | S |
| 6 | Chat | Make the "unlocked ₹88/kg for everyone!" event a highlighted system line. It is the best real-time moment for the demo (CH2) | P1 | S–M |
| 7 | Home + Admin | Same community snapshot on both screens: live buckets 7 vs 6, savings ₹41,290 vs ₹45,990, members 285/286/288 (A1) | P1 | S |
| 8 | Onboarding | Slide 2 body: say that everyone pays the final group price and the extra comes back (O1) | P1 | S |
| 9 | Orders | OTP copy: "Never share it in the chat" while the code arrives in a chat. Say "Street group" (R2) | P1 | S |
| 10 | Home / past cards | Two "Kasimedu Book & Meet: Whole Paarai · 14 Nov" rows with different statuses look like a duplicate order (H1) | P1 | S |

---

## Cross-cutting (data consistency)

- **X1 (P0): The same basmati order disagrees between screens.** This is ChatGPT's top issue, and I confirmed it plus several more.

  | Field | Where it says what |
  |---|---|
  | Pickup OTP | Order detail **5193** · OTP DM (`otp_dm.png`) **5350** |
  | Ananya's share | Order detail, hold sheet, chat: **10 kg / ₹880** · Vendor handover list and toast: **8 kg / "₹704 released"** |
  | Order ID | Order detail **JS-2043** · Hold success locked: "Order **JS-2045** is with Sri Balaji Traders", "View order **JS-2045**" (`bucket_golden_test.dart:400`) *(added)* |
  | Group total after Ananya's 10 kg | Detail: 82 kg + 10 kg = 92 kg, "8 kg more unlocks ₹88" · Hold success: "**97** of 100 kg · **3 kg** to go" *(added)* |
  | Who's in | Home: "Sunita (A-201), Arjun (B-702) and 4 others" (6) · Detail: "Meera, Ravi and 4 others" (6) · Live card: "8 joined" · Order: "8 neighbours" · Handover: "of **9** collected" *(added)* |
  | Closes | Hold sheet: "Tomorrow 4:30 am" · Chat card: "Closes 8:00 pm · 16h 35m left" · Home: "16h 25m left" *(added)* |

  - Fix: one fixture module per demo bucket (basmati, seer, paarai, pest, Koyambedu), imported by every golden and loaded by the server seed. Use Ananya = B-1204, 10 kg, held ₹960 → charged ₹880 → ₹80 back, OTP 5193, JS-2043, 8 households, 9th slot not shown. The vendor handover row and toast then read "Ananya · 10 kg" / "Handed to Ananya · ₹880 to you".
  - If the 8 kg row is meant to be someone else, give it a different name and flat. The chat bubble "Adding 8 kg so we all get 88" (Ananya) adds to the confusion. Give that line to another neighbour (e.g. Meera, A-303).
- **X2 (P0): Gemini's X1 (times) is not fully applied.** *(added)* The submission sheets still show:
  - Basmati pickup: hold success "Delivered to Clubhouse · Sat 14 Nov, **6:30 pm**". Order detail "Sat 14 Nov · **10:00 am–12:00 pm**". Vendor "Sat 10:00 am–12:00 pm". Also "Delivered to" vs "Show this at Clubhouse". Use "Pickup at Clubhouse · Sat 14 Nov · 10:00 am–12:00 pm" everywhere.
  - Paarai meet: detail "Kasimedu Fish Market, Gate 3 · **Sat 14 Nov, 2:30 pm**". Order detail "Kasimedu **Harbour**, Gate 3 · **Sun 15 Nov · 6:00 am**". Create "Kasimedu, Gate 3 · Sun 15 Nov · 6:00 am". Past cards "14 Nov". Pick one place name ("Kasimedu Fish Market, Gate 3") and one time ("Sun 15 Nov · 6:00 am", a fish market opens at dawn).
  - Seer close: home "9h 55m left" · detail "Closes in 2h 39m" · create success "closes Fri 1:30 pm". The golden clock and the fixture cutoffs probably disagree. Freeze the golden clock and derive "left" from the same cutoff.
- **X3 (P2): Pest-control hold amount.** *(added)* Wallet shows "Society Pest Control ₹480 · Held". The detail holds ₹400 at the current tier. If the hold was taken at the ₹480 tier, say so: "Held ₹480 · you'll pay ₹400 or less". Otherwise hold ₹400.

## Onboarding / auth

- **O1 (P1): Slide 2 explains the hold but not the best part.** The body says money goes to the vendor or comes back, but not that everyone pays the lower final price. Body copy: **"We block your share with UPI. When the bucket fills, everyone pays the final group price and any extra comes straight back. If it doesn't fill, the whole hold is released."** Keep the headline.
- **Dropped:** "replace the clay 3D onboarding art with realistic photos". The clay style is a deliberate brand choice for illustrations (the product vision prefers animated, not realistic). Products use photos, onboarding uses illustrations. That split is fine.
- **Dropped:** "skip login in the demo video". This is not a UI fix. It is already the video plan.

## Home

- **H1 (P1): Past cards show what looks like a duplicate order.** `cards past`: two "Kasimedu Book & Meet: Whole Paarai · 14 Nov · Split" rows, one "Market day", one "Completed", both "Met at the market · done". Remove one, or make them clearly different (different fish or date). Also "Market day" + "done" contradict each other on the first row.
- **H2 (P2): Small stat labels in the hero.** "live buckets / neighbours in this week / saved together this month" look about 10sp. Use 12sp minimum, `#FFFFFF` at 85% opacity.
- **H3 (P2):** The hero says "**32** neighbours in this week", but elsewhere the community has 285–288 members (A1). Fine as a different metric, but use the label "32 joined a bucket this week" so it doesn't read as the member count.
- ChatGPT confirmed the home reads as group buying. No change to direction.

## Buckets tab

- No new issues. (Gemini's H3 merge of the filter rows is visible: "Type ▾" + categories.)

## Bucket detail

- **D1 (P1): Say that "8 kg more" already counts your quantity.** Basmati: "8 kg more unlocks ₹88/kg for all 7 of you" sits next to the home card's "18 kg more". Both are right, but they look inconsistent. Copy: **"With your 10 kg the group reaches 92 kg. 8 kg more unlocks ₹88/kg for everyone."** Pest: **"You'll be flat #32. 18 more flats unlock ₹340/flat."**
- **D2 (P2): Market-trip markers.** "150 kg" and "300 kg" on the Koyambedu progress bar have no labels. Use "Min 150 kg" / "Tempo 300 kg" and show "186 kg booked · 62%".
- **D3 (P2, verify): Bottom bar vs last section.** ChatGPT thought the sticky bar hides the end of "How your money works". The sheets are mid-scroll captures, so I couldn't confirm. Scroll to the end on a device: the last card must clear the bar (bottom padding = bar height + system inset + 16dp).

## Hold

- No new issues beyond X1/X2 data (97 kg / JS-2045 / 6:30 pm). The hold sheet's demo caption (Gemini HD1) is in place.
- **Dropped:** ChatGPT's "DEMO PAYMENT · SIMULATED" banner on every money screen and renaming "Hold ₹960" to "Simulate hold ₹960". The one demo caption under the PIN pad already covers honesty. Banners on every screen would undercut the 50% UX score.

## Orders

- **R1 (P0): Two payout stories.** The buyer's order detail says "Paid to vendor ₹880 · Paid" as soon as the bucket fills. The vendor screen says "Paid to you each time a buyer collects with their OTP" and the handover releases the money. Keep the vendor model (it is the stronger trust story) and change the buyer receipt:
  - "Held with UPI ₹960 / **Charged at final price ₹880** / Back to your bank ₹80"
  - Add a caption below it: **"Sri Balaji Traders gets ₹880 when you show your pickup code."**
  - Hold success locked: "₹880 paid" → **"₹880 charged at the final price"**. Keep the pill "Charged at the final price".
  - This also tightens Gemini R1 (keep the three rows as a sum).
- **R2 (P1): OTP privacy copy contradicts itself.** "Never share it in the chat" (`order_screen.dart:220`) while the code is delivered in the Jugaad Street DM. Change to **"Show it to the vendor at handover. Never post it in the Street group."**
- **R3 (P2):** Market order detail says "Bucket full · order created". For a book-and-meet bucket use "Booked · pay at the stall" (same as Gemini R3, still visible on `order detail market`).

## Wallet

- **W1 (P2):** "At mark…" chip still cut off (Gemini W5, still open). Rename it to "Market" so all five chips fit at 360dp.
- Otherwise the wallet reads well. "Price dropped to ₹88/kg · ₹80 back to your bank" is in place.

## Create

- **C1 (P0): Pay-at-market cutoff copy talks about holds.** On `create step2 market` with "Pay at the market" selected, the helper still reads "If it fills by the cutoff, it becomes an order. If not, every hold is released." (`create_bucket_screen.dart:1228`). Pick the copy by pay mode:
  - Hold: keep the current text.
  - Market: **"If enough neighbours book by the cutoff, the trip is on. If not, the bookings lapse. Nobody pays anything until the stall."**
- **C2 (P1): Disabled "Pick a type to continue" button.** It is pale salmon with white text, which has low contrast. It also doesn't match the neutral disabled style the detail screen now uses (Gemini D2: `#EDEAE7` fill, `#9E9A96` text, see "Pick a cut first"). Use the same disabled style app-wide.
- **C3 (P2): Create success looks half-loaded.** The partly filled bar with "Opening your bucket" under a finished success state reads as stuck. Either make it a visible countdown ("Opening your bucket in 3…") that fills to 100%, or drop it and rely on the "View bucket" button.

## Chat (Nexconn)

ChatGPT said the live cards are "one of the most convincing parts" and feel native. "Live update after" is the best screen.

- **CH1 (P0): Duplicate system line.** "Ananya (B-1204) took 10 kg" appears twice in `street_chat.png`. The server posts one event per join (`service.js afterCommit`), so this is almost certainly left over from repeated test runs on the same channel. Before recording: reseed, and clear or recreate the Street channel so the history is clean. Optional: name the bucket in the event ("Ananya (B-1204) took 10 kg of Aged Basmati") so lines from different buckets can't look like repeats.
- **CH2 (P1): Make the price unlock its own moment.** The server already appends "…and unlocked ₹88/kg for everyone!" to the join event. Render events that contain an unlock as a distinct line: green tint `#E8F5E9`, dark green `#1B5E20` text, a trending-down icon, bold "₹88/kg unlocked for everyone". Put it in the demo right after the card's bar crosses 100 kg. This is the 30%-innovation beat.
- **CH3 (P2):** Chats tab row "Aged Basmati Rice (1…" + "Bucket" tag truncates the most important word. Drop "(1121)" from list previews, or move the "Bucket" tag under the title.

## Vendor

- **V1 (P0, part of X1/R1):** Handover row and toast "Ananya · 8 kg · ₹704 released" → "Ananya · 10 kg", "Handed to Ananya · ₹880 to you". The header "₹704 released to you" → "₹880 paid to you".
- **Dropped:** ChatGPT's "DEMO LISTING" tags on vendors and removing the ★4.8 rating. The vendors are clearly fictional demo data, and ratings are app data, not certifications. No rule is broken.

## Admin

- **A1 (P1): Snapshot disagrees with home.** Home: 7 live buckets, ₹41,290 "this month". Admin: "6 buckets live now", ₹45,990 "in November". Members: join screen 285, Street chat 286, admin 288 of 412. Use one snapshot (both screens read the same server stats) and one label: "saved together in November".
- **A2 (P2): Vendor application copy.** "Pesticide-free greens, twice a week" is an unverified health claim, close to the no-fake-certification rule. Use **"Fresh greens from Thiruporur, twice a week"**.
- **A3 (P2):** Header "Society · OMR, Thoraipakkam, Chennai · 412 flats" leaves "flats" alone on the second line. Drop "Society ·" or put "412 flats" in the progress line.

## Also from ChatGPT, not taken

- **Typography table (22/16/15/14/12sp).** This is generic. The only concrete problem it points to is H2.
- **Status-bar treatment differs between sheets.** That is a capture difference: the goldens have no system bar, the device shots do. Not an app bug. For the submission gallery, use one capture source per sheet.
- **Flow watermark placement.** Keep the watermark (rule). The advice not to overlay price or status pills on the watermark corner is sensible and already true on the shown cards.

## For the 60-second demo (ChatGPT's script, trimmed)

1. 0–6 s **Home**: society, neighbour avatars, ₹ saved together. "Instead of buying alone, your street buys together."
2. 6–16 s **Basmati detail**: ₹96 now, ₹88 at 100 kg, "with your 10 kg, 8 kg more".
3. 16–27 s **Street chat**: a neighbour joins, the card's bar moves, and the CH2 "₹88 unlocked for everyone" line lands.
4. 27–39 s **Money**: ₹960 held → bucket full → ₹880 charged → ₹80 back (wallet line).
5. 39–50 s **Vendor handover**: OTP 5193 entered, "₹880 to you".
6. 50–58 s **Admin**: savings, live buckets, vendor asking to join (business angle).

Steps 4–5 only work once X1, R1 and V1 are done. That is why they are P0.
