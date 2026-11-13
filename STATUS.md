# Jugaad Street — status (paused 2026-11-13, 10:20 IST)

Deadline: **Nov 22, 23:59 AoE**. Branch `dev`, all local (nothing pushed or published — the user decides when).

## Done
- **Server** (`server/`): API per `docs/CONTRACT.md`, Nexconn bot + live bucket cards via message metadata, UPI-hold
  sandbox, cutoff → orders with OTPs, wallet, vendor/admin, `/api/users` profiles. 19 tests. Seeded and verified live.
- **App** (`app/`, Flutter Android), every screen built, reviewed by Gemini, QA'd end to end on the emulator, fixed:
  splash (basket fills) + launcher icon, onboarding, OTP login, community join, **group-buying home** (hero, "Join your
  neighbours" goal cards, live street feed), Buckets tab, bucket detail for split/bulk/service/trip/book-and-meet,
  UPI hold + success, create bucket (templates, 3 taps), orders + pickup OTP, wallet, Nexconn chats (names, live cards,
  system pills, order/OTP cards), vendor handover by OTP, admin nudges. Golden screenshot harness at 412×915 and 360×800.
- **Brand**: logo = market basket holding three shares (`app/assets/brand/`), 29 Flow product/category/banner/onboarding images.
- **Docs**: `PLAN.md`, `docs/CONTRACT.md`, `docs/WRITEUP.md` (draft, has the App Key), `docs/VIDEO.md` (script + shots),
  `docs/review/` (Gemini review, QA report).
- **Film prep**: narration approved — Gemini "Charon" take 1, 50.4 s, `/mnt/storage/videoedit-media/jugaad-film/work/vo/narration.wav`
  (+ `narration_words.json` word times). Music candidates (5, Pixabay) in `/mnt/storage/videoedit-media/jugaad-film/music/`.
  Film stills were mid-generation in Google Flow (`art/candidates/`, project in Flow) when paused.

## Next (in order)
1. **Disk**: main disk is at ~0.7 GB free. Needs the user's OK to clear `~/.gradle/caches/build-cache-1` (1.9 GB pure cache).
2. Verify on device: splash/icon, new home, first login (fix landed after QA), vendor sign-out, hold sheet at 360.
3. Regenerate goldens against the re-recorded fixtures (`app/test/fixtures/`, recorded 10:15 from a fresh seed):
   `cd app && flutter test -t golden --run-skipped --update-goldens`.
4. Finish film art (resume the Flow work: stills in one flat/2.5D style, ≤ 40 Veo credits, ART.md/MUSIC.md), pick music.
5. ChatGPT review pass (Gemini done) → final polish.
6. Capture app footage on the emulator (re-seed first: stop API, `npm run seed`, start), build the <60 s film in
   `~/Documents/remotion/videoedit/projects/jugaad-film/` (product-film skill, Bioboon/MyFW style).
7. Traction: testers in real societies (APK), fill the write-up's traction section; write-up → PDF.
8. With the user's go-ahead: push repo public, APK release, reachable server, submit on Reskilll.

## How to run
- Server: `cd server && npm start` (port 8787; `npm run seed` with the server stopped resets demo data).
- App: emulator AVD `MyFW_Pixel9ProXL`, `adb reverse tcp:8787 tcp:8787`, `cd app && flutter run`.
  `app/build` and `app/test/golden/shots` are symlinks to `/mnt/storage/jugaad-street-build/` — never `flutter clean`.
- Demo logins (OTP 1234): Ananya 9000000001, Priya (admin) 9000000005, Sri Balaji (vendor) 9000000012.
