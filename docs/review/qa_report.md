# Jugaad Street: integrated QA pass (emulator)

**Date:** Fri 13 Nov 2026 · **Device:** emulator-5554, AVD MyFW_Pixel9ProXL (display override 720x1600), debug build
**Build tested:** flows A–J on `513da09` (the HEAD when QA started). The lead pushed 7 commits while QA was running (`176540a`..`5abdf8e`: brand mark, Gemini fixes, new home, splash). I rebuilt `5abdf8e` and re-checked the top bugs on it. Each bug below says whether it still happens on `5abdf8e`.
**Server:** `node src/index.js` on :8787, re-seeded before testing and again at the end. It is running and freshly seeded now.
**Evidence:** screenshots and logs are in `/mnt/storage/jugaad-street-build/qa/` (the `NN_*.png` numbers follow the walk order). Console logs: `flutter_console_part1.log` (513da09, flows A–H) and `flutter_console_head.log` (5abdf8e). `logcat_flutter*.log` holds the `flutter` logcat tag, which has the unhandled async exceptions.
**App code:** not changed. No compile errors were found and nothing was committed.

> Environment note: the emulator process died twice during the session, at about 09:50 and 09:57, both soon after an `adb shell pm clear` or force-stop. Host swap was nearly full (7.3 of 8 GB). I could not tie this to the app. I restarted the AVD with `emulator -avd MyFW_Pixel9ProXL -no-snapshot-save`, and it is running now.

---

## Bug list

Severity: **H** = blocks a demo path or loses data · **M** = visibly wrong or confusing in a demo · **L** = polish.

### 1. [H] (A, also Priya and any re-login) A seeded member lands on "Find your community", and "Join" leaves them stuck there
- **Steps:** `pm clear` → onboarding → phone 9000000001 → OTP 1234.
- **Expected:** Ananya already has a membership (`GET /api/me` returns Sea Breeze B-1204), so the app goes straight to Street home.
- **Actual:** the app shows "Find your community". Picking Sea Breeze, typing B-1204 and tapping **Join Sea Breeze Towers** succeeds on the server (`POST /join 200`), but the screen does not move. The only way out is to kill and relaunch the app, after which it opens on Street home. Priya (9000000005) gets the same result.
- **Cause:** in `otp_screen.dart`, `_verify()` calls `session.signIn()` first, which notifies the router. With no community yet, the router redirects to `/community/join`. `setCommunity()` runs afterwards, but since commit `cece85b` the router (`router.dart:45`) leaves `/community/join` reachable once a community is set, so nothing redirects to `/street`. After a manual join, `JoinCommunityScreen._join` only pops when `popOnJoin` is true, which it is not on this route.
- **Fix ideas:** set the community before `signIn` notifies, or batch both into one notify. Make `_join` call `context.go('/street')` when it was not opened as a sheet. Or redirect `/community/join` to `/street` unless it carries a query flag such as `?switch=1`.
- **Still on 5abdf8e:** yes.
- **Screenshots:** `06_after_otp.png`, `08_join_stuck.png`, `112_priya_after_login.png`, `126_head_join_after_otp.png`, `127_head_join_stuck.png`.
- **Files:** `app/lib/router.dart`, `app/lib/features/auth/otp_screen.dart`, `app/lib/features/community/join_community_screen.dart`.

### 2. [H] (H) The vendor dashboard never refreshes: unhandled exception in `_refresh`
- **Steps:** as Sri Balaji, open the JS-2045 handover tile → enter Ananya's OTP → collected → back. Then do a second handover (Meera) → back, then pull to refresh.
- **Expected:** the tile reads "2 of 7 collected" with the progress bar updated.
- **Actual:** it stays at "1 of 7 collected" after the second handover and after pull-to-refresh. The server already reports Meera and Ananya as collected. The first "1 of 7" only appeared after a full app relaunch. Logcat shows:
  `Unhandled Exception: setState() callback argument returned a Future ... _VendorScreenState._refresh (vendor_screen.dart:48)`
- **Cause:** `setState(() => _future = f);` is an arrow function, so it returns the assigned `Future`, and `setState` throws. `admin_screen.dart:111` has the same line, so admin pull-to-refresh is broken in the same way (found by reading the code; not exercised on device).
- **Fix:** `setState(() { _future = f; });` in both files.
- **Screenshots:** `107_handover_done.png` (handover itself works), `110_vendor_after_2nd_handover.png`, `111_vendor_after_pull.png`. Log: `logcat_flutter.log` at 09:47:10.
- **Files:** `app/lib/features/vendor/vendor_screen.dart:48`, `app/lib/features/admin/admin_screen.dart:111`.

### 3. [H] (H) A vendor cannot sign out
- **Steps:** log in as a vendor (9000000012). The app lands on `/vendor`.
- **Expected:** a profile or menu with Sign out, so the demo can switch back to a member.
- **Actual:** the vendor screen has no menu, and the avatar does nothing (`108_vendor_avatar_tap.png`). The router keeps a vendor on `/vendor`, `/chat` and `/orders`. I had to `pm clear` to log in as Priya. This blocks the H → I demo hand-off.
- **Files:** `app/lib/features/vendor/vendor_screen.dart` (`_Header`), `app/lib/router.dart`.

### 4. [M] (B, C, E, G) Hold sheet: the header overflows (yellow-black stripes). Worse on 5abdf8e
- **Steps:** open any bucket → Hold → the UPI sheet opens.
- **Actual:** on 513da09 the dimmed header (photo, title, subtitle) overflows by 3–5 px, and the stripes cross the subtitle. On 5abdf8e it overflows by **59 px**: the sheet grew (new "Your UPI app" card and demo note), and the title is hidden behind the sheet.
- **Cause:** the console points to `Column` at `hold_screen.dart:306`, inside `Expanded > SafeArea` with a fixed-height top area. When the sheet is tall, the header area is too short. Make the header scrollable or clip it, or drop the subtitle or photo when height is short (use a `LayoutBuilder`).
- **Screenshots:** `40_seer_hold_sheet.png`, `74_trip_hold.png` (3 px), `89_goat_held.png` (5 px), `129_head_hold_sheet.png` (59 px on 5abdf8e).
- **File:** `app/lib/features/hold/hold_screen.dart:~301–330`.

### 5. [M] (D) Book & Meet detail: the hero chip row overflows by 33 px
- **Steps:** open Kasimedu Book & Meet: Whole Paarai.
- **Actual:** "Book & meet" plus "Closes Sat 14 Nov, 10:00 pm" do not fit on one line. The second chip is cut off and covered by the overflow stripes.
- **Cause:** the console reports `Row` at `bucket_detail_screen.dart:512` (513da09), which is line ~528 on 5abdf8e, inside the `FlexibleSpaceBar`. Wrap the chips in a `Wrap`, put the date chip in `Flexible` with ellipsis, or shorten the label ("Sat 10 pm").
- **Still on 5abdf8e:** yes.
- **Screenshots:** `48_paarai_detail.png`, `128_head_paarai_detail.png`.
- **File:** `app/lib/features/bucket/bucket_detail_screen.dart` (`HeroAppBar`).

### 6. [M] (D) After booking your own half, a snackbar says "A neighbour just took one of your picks."
- **Steps:** paarai → pick Tail half → **Book my half**.
- **Actual:** the Booked screen appears with that snackbar. The half was taken by you.
- **Cause:** `_pruneDraft` runs on the refetch after the booking. The unit is no longer open, so it is dropped from the draft and the snack fires. Skip pruning (or the snack) when the unit's owner is me or `myShare` is set.
- **Screenshot:** `51_paarai_booked.png`.
- **File:** `app/lib/features/bucket/bucket_detail_screen.dart:101–112`.

### 7. [M] (G) Stale `js:otp` cards and bucket groups from earlier seeds reuse the same order numbers
- **Steps:** re-seed (as the README asks before a demo), then make the paarai order.
- **Actual:** the Jugaad Street DM shows **two** "Your pickup code · JS-2043" cards with different OTPs (5350 at Clubhouse from an earlier run, and 3177 now). The Chats tab also lists an "Aged Basmati Rice (1121)" bucket group from an earlier run, before basmati became an order in this session.
- **Cause:** Nexconn history survives a re-seed, while `counters.order` resets to 2040, so order IDs repeat. This looks bad on a recording.
- **Fix ideas:** start the counter from a time-based value, or have the seed delete or quit old `bucket_*` groups and clear the bot DM history.
- **Screenshots:** `62_direct_otp.png`, `61_chats_tab.png`.
- **Files:** `server/src/store.js:11,41`, `server/src/seed.js` (`seedNexconn`).

### 8. [M] (J) The home search field keeps focus, and the keyboard pops back over the bottom nav
- **Steps:** search "rice" → open a result → back. Later, return to Street from a Hold success screen.
- **Actual:** the search field gets focus back and the keyboard (once the emoji panel) reopens, covering the bottom nav. Tab taps then do nothing until the keyboard is closed.
- **Fix:** unfocus on scroll or on navigation (`FocusScope.of(context).unfocus()` before `push`, or `onTapOutside`).
- **Screenshots:** `68_tabs_unresponsive.png`, `69_state.png`.
- **File:** `app/lib/features/home/street_home_screen.dart` (`_SearchField`, `_searchFocus`).

### 9. [M] (C, E) The hold success copy says "The fish is cut…" for the goat (and any split)
- **Actual:** the Whole Goat success screen reads "The fish is cut once every part is taken."
- **Fix:** use the bucket noun ("The goat is cut…", or a neutral "Cut once every share is taken").
- **Screenshot:** `90_goat_success_after_lock.png`.
- **File:** `app/lib/features/hold/hold_success.dart:127`.

### 10. [M] (C/G) The hold success screen does not notice when the bucket locks while it is open
- **Steps:** take Hind leg (R) on the goat → success. Meera then takes the offal (via the API), which locks the bucket and creates order JS-2044.
- **Actual:** the success screen still says "6 of 7 shares taken · 1 share to go · Invite neighbours". Only **View bucket** shows "Bucket full, order sent".
- **Fix:** listen to the card metadata on the success page, as the detail page does, or refetch.
- **Screenshot:** `90_goat_success_after_lock.png` vs `91_goat_ordered.png`.
- **File:** `app/lib/features/hold/hold_success.dart`.

### 11. [M] (H) The profile menu shows "Vendor dashboard" to members
- **Actual:** Ananya and Priya both see the item. Tapping it opens a dead end ("This account is not a vendor." with a **Try again** button that cannot help).
- **Fix:** show it only when `user.role == 'vendor'`.
- **Screenshots:** `97_profile_menu.png`, `98_vendor_as_member.png`, `113_priya_menu.png`.
- **File:** `app/lib/features/home/street_home_screen.dart` (`_profileMenu`, line ~382 on 5abdf8e).

### 12. [M] (G) Past buckets: a confirmed Book & Meet shows "Didn't fill · holds released"
- **Actual:** Buckets → Past lists "Kasimedu Book & Meet… Market day" with the line "Didn't fill · holds released". It did fill (order JS-2043).
- **Cause:** `PastBucketRow` treats only `completed` as a success. `market_day`, `ordered` and `delivering` all fall into the "didn't fill" text.
- **Screenshot:** `63_service_filter.png`.
- **File:** `app/lib/features/bucket/bucket_card.dart:~238`.

### 13. [L] (D) The "Message" button on the Booked screen opens the Street chat titled "Sea Breeze Towers"
- **Actual:** the header reads "Sea Breeze Towers · 6 live". Everywhere else it is "Sea Breeze Street". You might also expect it to open a chat with the organiser (Ravi), not the whole street.
- **Screenshot:** `52_paarai_message.png`.
- **File:** `app/lib/features/hold/hold_success.dart:400` (title param).

### 14. [L] (5abdf8e home) The hero card's "Start a" button label is truncated
- **Actual:** the white button reads "+ Start a" ("bucket" is cut off), and "Street chat" wraps onto two lines.
- **Screenshot:** `120_head_home.png`.
- **File:** `app/lib/features/home/list_home_sections.dart` or `list_feed.dart` (new hero).

### 15. [L] (A) Search matches inside descriptions, so "rice" also returns Pest Control
- **Actual:** Pest Control appears for "rice", presumably through "p**rice**" in its text. The results list also keeps the old scroll offset, so the first card sits half under the pinned header (`20_search_rice.png`; `22_search_scrolled_top.png` is after scrolling up).
- **Fix:** match whole words or title-first, and jump to the top when the query changes.
- **File:** `app/lib/features/bucket/list_logic.dart` (`searchBuckets`), `street_home_screen.dart`.

### 16. [L] (J) Text truncated in the detail facts strip
- "Goes at 25 …" / "Goes at 10 …" (`64_pest_after_leave.png`, `85_create_posted.png`) and "14 kg dress…" (`88_goat_map.png`). The three equal columns are too narrow at 720 dp. Allow two lines or shorter labels.
- **File:** `app/lib/features/bucket/detail_widgets.dart` (facts strip).

### 17. [L] (J) Pressing back on the Buckets, Chats or Wallet tab exits the app
- **Actual:** system back on a non-Street tab root goes to the launcher (`32_unexpected.png`, after back from Buckets).
- **Expected (Licious pattern):** the first back returns to the Street tab.
- **Fix:** a `PopScope` in `HomeShell` that calls `goBranch(0)` when `currentIndex != 0`.
- **File:** `app/lib/features/home/home_shell.dart`.

### 18. [L] (wallet, past) Crab bucket has no photo
- **Actual:** "Pulicat Mud Crabs" uses the grey fish placeholder in Wallet and Past lists and on its detail page. `AppImages._bucket` has no `crab` key, although the contract lists `crab`.
- **Screenshots:** `47_wallet_released.png`, `128_head_paarai_detail.png` (first capture).
- **File:** `app/lib/core/images.dart`.

### 19. [L] (D) The order-detail map differs from the bucket and booked screens
- **Actual:** the bucket page and Booked screen draw the Kasimedu map (auction hall, gate, sea). The order page draws a plain blue block.
- **Screenshots:** `53_booked_bottom.png` vs `55_order_paarai.png`.
- **File:** `app/lib/features/orders/order_screen.dart`.

### 20. [note, not an app bug] The first seed of the session came out 5.5 h early, so the seer expired at boot
- **What happened:** the first seed wrote `seededAt 2026-11-12T22:03Z`, which is 03:33 IST, and `b_seer.cutoffAt` 07:00 IST. The host clock read 03:33 when the session started (`uptime`) and 09:25 IST a few minutes later (`date`). The system clock jumped about 5.5 h mid-session, so every relative time in that seed was in the past, and the scheduler ran `[cutoff] b_seer → expired` on boot. A re-seed after the jump was correct.
- **Takeaway:** check the clock or timezone (`date`) before the final demo re-seed. If the clock jumps after seeding, re-seed again.
- **Side note:** `pgrep -f "node src/index.js"` also matched my own shell, as the brief warned. `pgrep -x node -a | grep src/index.js` is safer.

---

## Works well

- **Onboarding:** 3 slides, Skip, phone (prefilled demo number), OTP with "Demo code: 1234", resend timer. `01`–`05`.
- **Street home (513da09):** banner carousel auto-advances (3 banners). The category grid has live counts. Tapping Fish switches to the Buckets tab with the Fish filter. "Closing soon" rail, savings card, Street chat entry with the latest activity, full cards with "You're in" or "Joined" state. `09`–`19`.
- **Street home (5abdf8e):** the new "Buying together" hero, "Join your neighbours" cards with avatars and tier progress, and "Happening on your street" feed all render without overflow. `120`–`125`.
- **Bulk (B):** qty stepper updates the price live (₹960 → ₹1,440 for 15 kg; "₹1,320 if 100 kg is reached"). PIN `0000` shows "Incorrect UPI PIN. No money was blocked." and PIN `1234` succeeds. The success page shows the "3 kg to go" invite. In the Street chat a `js:event` pill "Ananya (B-1204) took 15 kg" appeared, and the card metadata ticked 82 → 97 (logcat). Wallet "Held now ₹1,920, 2 buckets". `23`–`36`.
- **Split (C):** the seer share map with owner initials, cut style chips (Curry, Fry slices, Steaks), hold → "7 of 8 cuts taken". "You're in" card with "Leave and release ₹680". The confirm sheet releases the hold right away, and Wallet shows "Whole Seer ₹680 Released". The `js:event` "Ananya left: Steak 2 is open again. ₹680 hold released." was posted. `37`–`47`.
- **Book & Meet (D):** half tiles, cut options, "No prepayment" banner, Booked screen with the market map, "Who's coming" and "Every half is booked". The instant lock produced order JS-2043 with status `market_day`. `48`–`54`.
- **Service (E):** the tier chart ("₹400/flat now · You · #31 · Drops to ₹340 if 19 more flats join"). Leave and rejoin both work. `64`–`66`.
- **Trip (E):** the tempo bar with the 150 kg go-mark, Add → per-item steppers, a hold that includes the transport share. `71`–`75`.
- **Create (F):** the Rice sack template prefills everything (vendor, tiers, shop price, cutoff, pickup, live chat preview). Post lands on the new bucket. The new `js:bucket` card appears at the bottom of the Street chat, and tapping it opens the bucket. `76`–`87`.
- **Lock to order (G):** the goat split lock (Ananya plus Meera through the API) and basmati `close` both create orders. The `js:order` card ("Bucket filled · order placed", ₹1,460, View order) and the welcome pill appear in the bucket group. The `js:otp` DM shows a big 4-digit code. The Orders list (Active · 2, Past · 2) shows OTPs. Order detail has a big OTP, status stepper, everyone's lines with Paid / Due at market, and totals. Sending a group message works, and the keyboard does not cover the input. `55`–`62`, `90`–`95`.
- **Vendor (H):** the dashboard shows held demand, a "Hand over at the gate" tile, today's buckets and a packing list grouped by community. Handover: pick the buyer, enter the OTP. A wrong OTP shows a clear error. The right OTP marks the line collected, shows "₹1,440 released to you" and a snackbar. `102`–`107`.
- **Admin (I):** the avatar menu → Community admin shows membership, savings, quick actions, vendor approvals and "Needs a nudge". **Remind** changes to "Reminded" with a snackbar, and the nudge pill (megaphone, amber) appears in the Street chat. `113`–`118`.
- **Chat polish:** sender labels ("Meera · A-303"), JS bot avatar, readable previews in the Chats list, Street pinned on top, unread badges, bucket group header "2 neighbours + Murugan Fish Stall".
- **Back navigation** in pushed routes (detail ↔ hold ↔ order ↔ chat) behaves as expected. No red error screens and no crashes in the app.

## Not covered / notes

- Landscape was skipped as instructed. Hero transitions looked smooth from card to detail, but I did not check them frame by frame. I did not test the "I'm here" check-in, vendor approve/decline, or community switching (beyond opening the sheet, `119`).
- The emulator restarted twice (see the note at the top). After that, the app ran without `flutter attach` on the second AVD boot, so later layout errors are confirmed visually rather than through the console.
- I did not run Gradle beyond the two `flutter run` builds, and stopped it (`./gradlew --stop`) afterwards.
