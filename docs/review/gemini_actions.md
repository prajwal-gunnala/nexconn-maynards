# Design review: action list

Built from Gemini's three answers (raw text in `gemini_review.md`). I checked each point against the sheets, the full-size PNGs in `app/test/golden/shots/` and, where needed, the code.

- **Merged:** duplicate points.
- **Fixed:** points where Gemini misread the screen.
- **Added:** issues I found while checking.
- **Dropped:** advice that breaks product rules: no real payment, keep the Flow watermark, keep the Licious look, and no made-up certifications or NPCI branding.

Priority key: **P0** do before the demo video, **P1** if time allows, **P2** nice to have. Effort: S is under 30 min, M is about 1–2 h.

## Top 10, in order

| # | Area | Action | Pri | Effort |
|---|------|--------|-----|--------|
| 1 | Home | Explain "bucket" on the home screen in one line (H1) | P0 | S |
| 2 | Cross-cutting | Make the dates and times match across bucket, hold, order and wallet screens for the same bucket (X1) | P0 | S–M |
| 3 | Hold | Make the hold-success subtitle read as safe, not as a warning (HD2) | P0 | S |
| 4 | Hold | Present the PIN pad as a stand-in for the UPI app, not an in-app PIN pad (HD1) | P0 | S |
| 5 | Wallet | Explain *why* money came back ("price dropped to ₹88/kg, ₹80 back") (W1) | P0 | S |
| 6 | Home | Replace the red count badges on the category icons with "2 live" pills (H2) | P1 | S |
| 7 | Cross-cutting | Use one style for the selected chip (brand fill), not brand on some screens and black on others (X2) | P1 | S |
| 8 | Hold | Make "Copy invite for neighbours" a real secondary button. Viral fill is the demo story (HD3) | P1 | S |
| 9 | Bucket detail | Fix truncated app-bar titles (D1) | P1 | S |
| 10 | Discovery | Merge the two filter rows on the Buckets tab into one (H3) | P1 | M |

---

## Cross-cutting

- **X1 (P0): Dates and times disagree between screens.** Judges will notice in a walkthrough.
  - Basmati: hold success says "Delivered to Clubhouse · Sat 14 Nov, 10:30 am". The order list and order detail say "Pickup at Clubhouse · Sun 10:00–11:00 am".
  - Paarai: bucket detail says "Kasimedu Fish Market, Gate 3 · Sat 14 Nov, 6:29 am". The order detail, order list and create step say "Sun 15 Nov, 6:00 am" / "Sun 6:00–7:00 am". "6:29 am" looks like a time worked out from "now", not one a person would pick.
  - Fix: build every meet and pickup time from one fixture field per bucket, rounded to :00 or :30. Show the same format everywhere: "Sun 15 Nov · 6:00–7:00 am".
- **X2 (P1): Two styles for the selected chip.** The Buckets tab category "All" and the Wallet "All 4" use a black fill. The type tabs, cut chips and create chips use a brand outline or fill. Pick one: selected = `#E4572E` fill with white text (or brand-tint fill with a brand border), on every filter row.
- **X3 (P2): Too many accent colours.** There is brick-tomato, an ochre/amber (hold step 1, "UPI Reserve" pill, held strip), a bright green (savings) and a black chip. Fix to one token each: brand `#E4572E`, held/pending amber (one value), success/savings green (one value, e.g. `#1E8E3E`). Use green only for savings and completed states, and amber only for "held".

## Onboarding / auth

- **O1 (P1): Contradictory headline on onboarding slide 2.** "Your money is held, never paid, until the bucket fills" says both "never" and "until". Change to **"Your money is held, not paid, until the bucket fills"**.
- **O2 (P2): Long Join subtitle.** Shorten to "Everyone in your society buys together in one Street chat." Darken the grey to at least `#6B6B6B` for contrast.
- **O3 (P2): Phone field "pin".** The red teardrop under the cursor is Android's text-selection handle, which the golden capture picked up. It is not a bug, but unfocus the field (or hide the handle) in shots used for submission.
- **Gemini error, dropped:** "three dots but only two onboarding screens". There are three slides (third: "One order, one delivery to your gate", `welcome_screen.dart`). The sheet only showed two. Optional: add a golden for slide 3.

## Home / discovery

- **H1 (P0): The 5-second test fails.** Nothing on the home screen says what a bucket is. "Shop by category / Everything your street buys together" reads like any grocery app.
  - Under the search bar or above the categories, add a one-line explainer (14sp, brand-tint card, 12dp padding): **"A bucket is one big order your neighbours split. Join one at wholesale price, or start your own."** Put a small "Start a bucket" text button on the right.
  - Rename "Shop by category" to **"Buckets by category"**.
  - Gemini suggested "Start a new bucket" as the category header. I didn't use that: tapping a category lists buckets to join, so that header would mislead.
- **H2 (P1): Category badges look like notification counts.** Replace the red "1"/"2" badges with a small pill under the label: "2 live" (10sp, green tint `#E8F5E9` with dark green `#1B5E20`, or brand tint). The Licious category grid has no badges.
- **H3 (P1): Two stacked filter rows on the Buckets tab** (type: All/Split/Bulk/Service/Market trip, plus category: All/Fish/Meat/Fruits). This uses about 110dp of vertical space. Keep the category chips and fold type into a single "Type ▾" chip at the start of the row. Or keep the type tabs and drop the category row on this tab.
- **H4 (P2): Split/Bulk/Book & meet corner tags.** Inset 8dp from the card's top-left and use the same radius as the timer pill, so they don't look stuck on.
- **H5 (P2): Hero banner text.** "Whole seer split eight ways, landed at dawn" sits on a busy photo. Add a bottom-to-top dark gradient (0→60%) behind the copy.
- **Dropped:** making the "Join +" button a pill. Licious uses rounded-rect "Add +" buttons, so keep it.
- **Dropped (wrong):** "₹96 and ₹135 bleed together on the home rail". The gap is fine at full size.

## Bucket detail

- **D1 (P1): Truncated titles.** "Society Pest Control (Gel +…" and "Kasimedu Book & Meet: W…". Options: let the collapsing app bar wrap to two lines (18sp), or use a short title in the bar ("Pest Control", "Book & Meet: Paarai") with the full name in the body heading.
- **D2 (P1): Disabled "Hold with UPI" before a cut is picked.** At brand colour and 40% opacity the label is hard to read. Use a neutral disabled style (`#EDEAE7` fill, `#9E9A96` text). Change the label to "Pick a cut to hold" so the reason is on the button.
- **D3 (P1): Trust at the moment of decision.** Once the fish has scrolled to the cut picker, the seller row ("Murugan Fish Stall ★4.8, started by Ravi, C-801") is off screen. Add a 1-line seller row above "Neighbours in" (24dp avatar, name, ★ rating) or put the seller name in the hold sheet header (it is already there for basmati).
  - Dropped Gemini's "FSSAI Verified" tag: we can't claim a certification we don't have. Use "Verified stall" only if the data supports it.
- **D4 (P2): Neighbour names should carry flats.** "Ravi, Sunita and 4 others" becomes "Ravi (C-801), Sunita (A-302) and 4 others". This matches the "started by Ravi, C-801" pattern and makes it feel like a real society.
- **D5 (P2): Fish diagram letters.** The letters in the cut segments (S, R, M, K, P, A) are the initials of the neighbours who took each cut. Gemini read them as cut labels, so a first-time user may too. Add "Letters = neighbour who took it" to the legend line ("2 open · 6 taken · Your pick"), or draw them in the same avatar style as "Neighbours in".
- **D6 (P2): Money row on "Neighbours in".** Move "₹3,680 held so far" next to "6 of 8 cuts taken" ("6 of 8 cuts · ₹3,680 held") so it reads as part of the progress bar.
- **D7 (P2): Pest-control step chart.** Add a 15–20% brand fill under the line and set the tier labels (₹480/₹400/₹340) to 14sp bold so the price drop reads at a glance.
- **Gemini error, dropped:** "trust banner sits below the CTA". The "Held, not paid · released automatically…" strip is already above the price and Hold button in the bottom bar (`detail_sections.dart`).

## Hold (sheet + success)

- **HD1 (P0): In-app UPI PIN pad looks like phishing to fintech-aware judges.** Real payment is out of scope, so don't remove it. Instead, make it clear this screen stands in for the UPI app:
  - Title the sheet area "Your UPI app" with the bank row on top.
  - Add a 12sp caption under the dots: "Demo: in the live app this step opens your UPI app. Your PIN never touches Jugaad Street."
  - Dropped: Gemini's "Powered by NPCI UPI AutoPay" tag. AutoPay is the wrong mandate type, and we must not use NPCI branding.
- **HD2 (P0): Hold success subtitle.** "Blocked in your bank, not paid" is brand orange right under a green check, so it reads as a warning. Use the held amber at 600 weight, or neutral `#3A3A3A`, and change the copy to **"Held in your bank · not paid yet"**. This matches the hold sheet's "Held in your bank now".
- **HD3 (P1): "Copy invite for neighbours"** is the virality step, but it looks like a faint link. Make it a full-width outlined button (1dp `#E4572E` border, brand text, share icon, 48dp tall). Optionally add "Share on WhatsApp" next to it.
- **HD4 (P2): "View bucket" secondary button** has almost no visible border. Give it a 1dp `#E4572E` border with brand text and a 12dp gap from "Back to Street".
- **HD5 (P2): Dark area above the hold sheet.** In `hold_sheet_3digits` the top ~30% is solid dark. Check on a device. If the bucket detail isn't visible behind it, use a 50% black scrim over the detail screen, or shorten the sheet. Most likely the golden test pushes the sheet on an empty route.
- **HD6 (P2): Success stepper** shows a green line from step 1 to the pending step 2. Make the segment going into a pending step grey.

## Orders

- **R1 (P2): Order detail, "Your share" receipt.** Gemini wanted to remove the "Paid" badge next to ₹880. I'd keep it, because it shows held → paid → released in one place. Make the three rows read as a sum: "Held with UPI ₹960 / Paid to vendor ₹880 / Back to your bank ₹80" with a divider above "Saved vs shop price".
- **R2 (P2): OTP digits.** Reduce the gap between the digit boxes to 12dp and centre the group, so "5 1 9 3" reads as one code.
- **R3 (P2): Market order.** The orders list shows "Order created" for a Book & Meet bucket. Use "Booked · pay at stall" so it isn't confused with the UPI flow.

## Wallet

- **W1 (P0): Partial release isn't explained.** "Saved ₹440 · ₹80 released" on a Paid item is confusing. Change it to **"Price dropped to ₹88/kg · ₹80 back to your bank"**. Do the same for bananas: "₹24 back".
- **W2 (P1): Summary cards are cramped.** "Paid this month" wraps. Use labels "Held", "Paid", "Released" (12sp) over values (18sp), with "this month" in the hero card subtitle.
- **W3 (P1): Released total.** The "Released ₹600" card counts only the crab bucket, while the history also shows ₹80 and ₹24 partial releases. Either include them (₹704) or label the card "Unfilled buckets".
- **W4 (P2): Hero copy.** "Saved with neighbours, 2026" becomes "Saved with neighbours this year". Left-align the "₹440 this month" pill with ₹524, 12dp below it.
- **W5 (P2): Filter chips.** "At mark…" is cut off at the screen edge. Fine for a scrolling row, but add 16dp end padding so the last chip can scroll fully into view.

## Create

- **C1 (P2): Success card.** "closes Fri 13 Nov, 5:30 am" leaves "am" alone on its own line, and the "Live" tag is cramped. Use the short form "closes Fri 5:30 am" and put "Live" on its own line or as a top-right corner tag. Check this time against X1, since the seer card elsewhere says "1h 55m left".
- **C2 (P2): Post CTA.** Gemini called the leading send icon off-centre. A leading icon with a centred label is standard Material, so only check that icon and label are centred as one group. Low.

## For the judges (demo polish, beyond fixes)

- Show the bucket filling live: in the 2-minute video, have a second phone or seeded bot claim a cut and the card's progress bar and "₹ held so far" visibly move. This uses Nexconn real-time chat, which ties to the 30% innovation score.
- End the demo on the wallet with W1's copy visible ("price dropped, ₹80 back"). That one line shows the whole held → paid → released idea.
- Gemini's "marquee ticker" and "AI faces for avatars" are dropped: they add noise, and initials with flat numbers (D4) carry more trust.
