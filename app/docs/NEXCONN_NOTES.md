# Nexconn notes (Flutter)

What we changed to make the Nexconn Chat UI kit build and work, and what we learned. Keep this current.

## Versions
| Thing | Version |
|---|---|
| Flutter / Dart | 3.47.7 / 3.13.5 |
| `ai_nexconn_chatui_plugin` | 26.2.11 (vendored, see below) |
| `ai_nexconn_chat_plugin` | 26.2.11 (direct dep, for `AreaCode`) |
| `rongcloud_im_wrapper_plugin` | 5.32.8 (pinned by the kit) |
| AGP / Kotlin / Gradle | 9.1.0 / 2.4.0 / 9.3.1 (Flutter 3.47 template, unchanged) |
| compileSdk / minSdk | 36 / 24 |
| google_fonts | 9.0.0 |

## Build fixes
1. **Plugin class name mismatch (blocker).** The published kit's pubspec says
   `pluginClass: AiNexconnChatUIPlugin`, but the file is `AiNexconnChatuiPlugin.kt`
   (the class inside is `AiNexconnChatUIPlugin`). Flutter's check is case-sensitive on
   Linux, so `flutter build` aborts with "doesn't have a main class defined".
   Fix: the kit is vendored at `app/third_party/ai_nexconn_chatui_plugin/` (identical copy,
   `example/` and the stray `android/app` removed) with the file renamed to
   `AiNexconnChatUIPlugin.kt`, and a duplicate `com/example/...` copy removed. `pubspec.yaml`
   uses `dependency_overrides` → `path: third_party/ai_nexconn_chatui_plugin`.
   Upgrading the kit = re-copy from pub cache and redo the rename.
2. **Namespace/applicationId** `in.maynards.jugaadstreet`. Kotlin needs `` `in` `` (keyword)
   in the `package` line of `MainActivity.kt`, but Gradle `namespace`/`applicationId` must be
   plain strings without backticks.
3. **Low-memory Gradle** (`android/gradle.properties`): `-Xmx2g`, `workers.max=3`,
   `kotlin.daemon.jvmargs=-Xmx1g`. The laptop is shared; run `./gradlew --stop` when done.
4. **media_kit** (pulled in by the kit for video) downloads `libmpv` jars for every ABI on
   the first build (~100 MB in `build/`). Debug builds for the emulator can use
   `--target-platform android-x64`.
5. **google_fonts 9** is built on the decoupled `material_ui` package; its `*TextTheme()`
   helpers return a different `TextTheme` type. We set `ThemeData(fontFamily: GoogleFonts.plusJakartaSans().fontFamily)`
   and build styles with `GoogleFonts.plusJakartaSans(...)` (plain `TextStyle`) instead.
6. `MaterialApp.router` must include `NexconnChatUILocalizations.localizationsDelegates`
   / `supportedLocales`, or ChatPage strings fail.

7. **Kit patch (cosmetic):** `third_party/.../views/chat/bubble/core/message_bubble_layout.dart`
   (`// JUGAAD PATCH`) — when a custom bubble builder is used, the kit no longer wraps it in its
   own coloured bubble with 10px padding, so our cards draw their own chrome. Re-apply on upgrade.

8. **Core library desugaring** — `flutter_local_notifications` (from the kit) fails
   `checkDebugAarMetadata` without it. `android/app/build.gradle.kts`:
   `isCoreLibraryDesugaringEnabled = true` + `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")`.
9. **Init race** — ChatPage queries `NCEngine` on its first build and asserts if the engine
   isn't initialized. `GroupChatScreen` shows "Connecting to chat…" until
   `NexconnService.state` is connected (or it has connected once this login).
10. `app/build` is a symlink to `/mnt/storage/jugaad-street-build/app-build` (main disk is
   nearly full). Don't `flutter clean` (it deletes the link); empty the target dir instead.

## API facts (verified in source)
- Providers wrapper is `NexconnChatUIProviders` (README's `ChatUIProviders` doesn't exist).
- `EngineProvider.initialize(InitParams(appKey, areaCode: AreaCode.sg))` → then
  `NCEngine.registerCustomMessage('js:bucket', CustomMessagePersistentFlag.counted)` etc. →
  then `EngineProvider.connect(ConnectParams(token: ...), handler: (userId, error) {...})`.
  `AreaCode` is not re-exported by the UI kit; import it from `ai_nexconn_chat_plugin`.
- Connect success: `error == null || error.code == 0`; `34001` = already connected (success);
  `31004` = bad/expired token.
- `NCEngine.add*Handler(key, handler)` is keyed, so our handlers (key `jugaad_street`) coexist
  with the kit's.
- `EngineProvider.disconnect()` marks the engine to be destroyed before the next
  `initialize`, so after logout we re-run init (which re-registers custom types).
- `ChatPage(customMessageBubbleBuilders: {MessageType.customMessage: (ctx, msg, config) => ...})`
  (also on `ChatPageConfig`). The builder replaces only the bubble content; avatar, sender
  name and time are still drawn by the kit.
- `CustomMessage.fields` is a `Map?`; `CustomMessage.messageIdentifier` is the type
  (`js:bucket`). `Message.metadata` is the expansion `Map?`; `Message.messageId` is the UID.
- The kit's `onMessageMetadataUpdated` only refreshes the **channel list**; ChatPage does not
  rebuild bubbles on metadata changes. Our `BucketCardBubble` subscribes to
  `NexconnService.watchMetadata(messageId)` and redraws itself.
- `Message.setMetadata(map, handler)` = `updateMessageExpansion` on the client.

## Spike results (emulator, Nov 13; user `u_test_a` in `test_street_1`)
Screenshots: `docs/spike/01_street_chat_card.png` (card rendered via ChatPage),
`02_after_server_meta_97.png` (live redraw after the server `meta` call),
`03_client_setMetadata.png` (client set returns 0), `04_fresh_install_history.png`
(fresh install shows the latest value). With the real server (Ananya, 9000000001 / 1234):
`05_welcome`, `06_phone`, `07_after_otp` (home), `08_street_chat_seeded` (7 cards + js:event),
`09_basmati_before` → `10_basmati_after_join` (another neighbour joined via the API: 82 → 87 kg
live), `11_bucket_detail` (card tap), `12_chats_tab`.

| Question | Answer |
|---|---|
| Do server-sent `content` JSON keys arrive as `CustomMessage.fields`? | **Yes.** `{bucketId, type, title}` arrived as `fields` (all strings) once `js:bucket` is registered after init / before connect. `messageIdentifier == 'js:bucket'`, `messageType == MessageType.customMessage`. |
| Does `message.metadata` come with history loads? | **Yes, but it can be stale.** `canIncludeMetadata=true`; on a fresh install the history copy carried the **original** metadata from send time (`filled:82`) even though the server had updated it to 98. The SDK then replays every later change as `onMessageMetadataUpdated` events right after connect (92 → 97 → 98). After that the local DB copy is current (a hot restart loaded 92 straight from history). **So never trust the history copy alone: always merge live updates** — `NexconnService.metadataFor(message)` overlays a per-messageId cache that is filled even before the bubble is built. |
| Does `onMessageMetadataUpdated` fire? | **Yes**, within ~1 s of the server `/v4/channel-type/message/metadata/set` call; `event.metadata` holds the changed keys, `event.message.metadata` the merged map. The kit's ChatPage ignores it (only refreshes the channel list), so `BucketCardBubble` listens to `NexconnService.watchMetadata(id)` and redraws (progress bar animates). |
| Can the client call setMetadata on a server-sent `hasMetadata` message? | **Yes, it succeeds (code 0) and persists server-side** (a fresh install replayed it), **but the sender gets no `onMessageMetadataUpdated` for its own change** — `NexconnService.setMetadata` emits locally on success. Product rule: only the server writes card metadata (it owns the truth); clients call the REST API. |
| Connect | `code 0` first time; `34001` after a hot restart (treated as success, `userId` is null then). |
| Event replay | On connect, the SDK replays every metadata change since the message was sent, oldest first (seen: 82→92→82→92→82→87 for basmati, matching the server's join/leave history). Last event = server truth. |

## Known gaps / next steps
- Sender names and channel titles show raw ids (`jugaad_bot`, `u_meera`, `Group street_c_seabreeze`)
  and the channel preview says `[customMessage]`. Fix with `ChatPageConfig.profileProvider` /
  `ChannelConfig.profileProvider` (resolve names from our API) and a channel item builder.
- `js:event` renders inside the avatar row; it could become a centred system line.
- Real photos: drop `assets/images/<imageKey>.jpg` (seer, basmati, …) and `BucketPhoto` uses them.
- Push notifications not set up (`enablePush` off).

## Run it
```
adb reverse tcp:8787 tcp:8787
cd app && flutter run -d emulator-5554                    # normal: Welcome → login → home
# spike/dev without the server (u_test_a in test_street_1):
flutter run --dart-define=DEV_NEXCONN_TOKEN=$(node ../scripts/nexconn-dev.mjs token u_test_a "Test A" | jq -r .body.result.accessToken) \
  --dart-define=DEV_START=/chat/group/test_street_1
node scripts/nexconn-dev.mjs meta test_street_1 D1Q5-PBV4-V1ED-UM02 '{"p":"{\"filled\":95,\"target\":100}","s":"live"}'
```
In dev-token mode a long-press on a `js:bucket` card calls client `setMetadata` (+1 filled).
