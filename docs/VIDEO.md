# Jugaad Street — pitch film (under 60 s)

16:9 1920×1080 for the submission (YouTube or Drive), plus a 9:16 cut from the same build if time allows.
Built in `~/Documents/remotion/videoedit/projects/jugaad-film/` following the `product-film` skill, the Bioboon film
(text synced to the voice word by word, text slides in from the right, no frozen stretches, logo on "Meet …", end card =
logo + phone + app icon) and MyFW (kinetic type, real app footage).

**Voice:** Gemini "Charon" from AI Studio, same as Bioboon. Direction: *warm, unhurried Indian-English product narrator,
natural breaths, one continuous flowing thought per paragraph, a small smile on "Jugaad Street".*
**Look:** animated, not too realistic. Flat and 2.5D illustration for the market world (Google Flow stills, animated in
Remotion with parallax and subtle Veo motion only where it earns it); real app screens from the emulator for the product.
Brand: brick-tomato `#E4572E`, tint `#FFF1EC`, ink `#1F1A17`, Plus Jakarta Sans.
**Music:** one light, warm track with a pulse (Flow music or Pixabay), ducked under the voice.

## Script (≈125 words, pitch order: problem → solution → unique → how it's built)
| # | Beat | Narration |
|---|---|---|
| 1 | Problem | Every Sunday at the fish market, it's the same problem. A whole seer costs far less than the steaks, but it's too much for one family, so we buy small and pay more. |
| 2 | Solution | Meet Jugaad Street. Anyone in your community starts a bucket: a whole fish, a hundred kilos of rice, pest control for the whole tower. Neighbours claim their share right inside the society chat. |
| 3 | Unique | Your money is only held, never paid, until the bucket fills, and if it doesn't, it's released automatically. Or simply book your half and meet at the market. |
| 4 | How it's built | Every claim updates live for everyone, built on Nexconn's real-time chat. |
| 5 | Close | A full bucket becomes one order, one delivery to the gate. Wholesale prices, for your whole street. |

## Shot list (times are estimates until the voice is timed)
| s | Shot | On-screen text (the spoken words, word by word) |
|---|---|---|
| 0–9 | Dawn fish market, animated: boats, crates, a whole seer on ice. Price tags flip: **₹950/kg whole** vs **₹1,400+/kg steaks**. A small family looks at the huge fish. | "same problem" → "too much for one family" → "buy small, pay more" |
| 9–11 | Iris to tint; logo builds, "Jugaad Street". | "Meet Jugaad Street" |
| 11–20 | Phone (home screen, real capture). Three bucket cards lift out one after another: whole fish, 100 kg rice, tower pest control. "Anyone" with avatars of an admin, a neighbour, a vendor. | "a whole fish" · "a hundred kilos of rice" · "pest control" |
| 20–26 | Street chat (real capture). The live bucket card fills; avatars pop on each claimed cut. | "claim their share" |
| 26–35 | UPI hold sheet → a shield and "Held" chip; the bucket fills → "Paid"; a second bucket fails → "Released". Then a map pin at Kasimedu Gate 3 with two avatars: "book your half". | "held, never paid" · "released automatically" · "book your half" |
| 35–41 | Three phones side by side; one claim, all three cards update together. Nexconn wordmark + "real-time chat"; Flutter mark small. | "updates live for everyone" |
| 41–49 | Bucket full → order list with flats → a crate at the society gate, OTP handover; savings counter rolls to ₹2,840. | "one order" · "one delivery" |
| 49–56 | End card: logo, phone on home screen, app icon, "Wholesale prices for your whole street". | "Wholesale prices, for your whole street." |

## Production steps
1. Voice: AI Studio Charon, one take per paragraph → transcribe for word times → `timeline.ts`.
2. Art: Flow stills (market at dawn, seer on ice, family, society gate, crate) in one flat-illustration style; at most
   2–3 short Veo Fast clips (≤ 60 credits total) for subtle motion (water, boats).
3. App footage: emulator `MyFW_Pixel9ProXL`-class AVD, demo-mode status bar, seeded demo data in the exact states the
   story needs (claims mid-fill, a hold sheet, a filled order).
4. Scenes: one agent per scene group from a written brief; lead reviews stills; preview → fix → export → −14 LUFS master.
5. Copyright check (`scripts/copyright_check.py`) before export.
