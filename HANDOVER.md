# Handover

Snapshot for a new session / dev picking this up. Pair with
[`README.md`](README.md) — that one explains *what the app is and how it's
built*. This one explains *what's queued, what's tricky, and the
non-negotiables*.

---

## 1. Where we are right now

Branch: `main`. Latest commit: `2d91ead` — drop the played-position
readout from each watch-history row (title + relative time only).

The previous session shipped the eight backlog features that the
HANDOVER had queued, plus follow-up fixes after the first install on
the Oppo CPH1719 (Android 7.1.1) device:

```
2d91ead  Watch history: drop the played-position readout
c61c100  Sync ios/Podfile.lock with audio_session / audio_service / sqflite_darwin
4a90e71  Subtitle toggle in player
f173779  Watch history: return mutable list when log file is absent
537ef6e  Pin ic_notification drawable through release resource shrinker
077abf3  Picture-in-Picture (Android) with iOS no-op fallback
97d32d6  Accept shared URLs / text from other apps
a04c9f4  Landscape gesture controls (brightness / volume / seek)
6e4368b  Watch history under Settings
c882e1a  Storage management subscreen under Settings
e62b95d  A-B segment loop in player
0dd00f6  Subtitle styling settings
8a57615  Search filters: sort / duration / upload date
4e4253c  Add HANDOVER.md for the next session
```

App is now feature-complete against the original backlog. See README
§Features for the full inventory; settings now hosts Subtitles /
Storage / History subscreens. Gesture overlay + PiP button live in the
landscape player.

---

## 2. Non-negotiable rules

These are durable instructions from the user. They apply to every
change the next session ships.

### 2.1 One commit per feature or bug fix, push immediately

- After analyze passes and the app builds, commit + push **right away**.
- Never batch multiple unrelated items into one commit.
- Commit subject: imperative present. Body: explain the *why* + call out
  cross-platform coverage. Footer: `Co-Authored-By: Claude Opus 4.7
  (1M context) <noreply@anthropic.com>`.
- Multiple items in one user turn → multiple commits, one per item.

### 2.2 Cross-platform required (Android + iOS)

- Every feature must work on **both** Android and iOS before it's "done".
- Pick cross-platform Dart/Flutter APIs first.
- Third-party packages: verify pub.dev shows both `android` and `ios`
  badges before adding.
- Native code? Implement **both** sides before merging. Existing
  examples are good references:
  - `android/app/src/main/kotlin/.../MainActivity.kt` extends
    `AudioServiceActivity` and registers the `yt_offline/share` +
    `yt_offline/pip` MethodChannels.
  - `ios/Runner/AppDelegate.swift` mirrors the channels and forces
    orientation via `requestGeometryUpdate`.
  - `ios/Runner/Info.plist` lists `UIBackgroundModes=audio`, the
    `ytoffline://` CFBundleURLTypes scheme, and supported orientations.
- Guard platform-specific Dart code with
  `defaultTargetPlatform == TargetPlatform.iOS` etc.

---

## 3. Decisions made last session (open questions resolved)

The previous HANDOVER §8 listed five open questions. The calls that
shipped (the user signed off on each by accepting the build):

| Question | Resolution |
|---|---|
| Watch History placement | Settings sub-screen (not a bottom-nav tab). |
| iOS external share intake | URL scheme only (`ytoffline://`). Share Extension target deferred. |
| A-B loop persistence | Session-scoped. Resets on track change. |
| Storage cleanup actions | One-shot "Delete N watched (X MB)" with confirmation. No auto-delete-by-age. |
| Subtitle styling preview | Static preview card on the Settings → Subtitles screen. |

---

## 4. Suggested follow-ups (not requested yet)

Things noticed while shipping that a future session might pick up — all
optional, none blocking:

- **Re-download captions for an existing video.** Subtitles are
  resolved once at download time
  ([youtube_stream_datasource.dart](lib/features/download/data/datasources/youtube_stream_datasource.dart)).
  If a video was downloaded before YouTube exposed captions, it never
  gets them. Would need a "Re-fetch subtitles" action in the library
  tile menu.
- **iOS Share Extension target.** The lighter URL-scheme path works
  but only when other apps know the `ytoffline://` scheme. To appear
  in the iOS share sheet for arbitrary YouTube links the app needs a
  Share Extension target added in Xcode.
- **iOS Picture-in-Picture.** Currently a no-op on iOS because
  media_kit drives playback through libmpv (CoreAudio + custom
  surface) rather than AVPlayer, so AVPictureInPictureController can't
  attach. Genuine iOS PiP would need a sample-buffer-display-layer
  bridge — substantial work.
- **Watch history list could mark videos that have since been deleted
  from library** more prominently (currently a warning icon on the
  trailing edge).

---

## 5. Existing traps to avoid (learned the hard way)

These all bit us already. Don't waste cycles re-discovering them.

| Trap | Where | Fix |
|---|---|---|
| `audio_service` requires `MainActivity` to extend `AudioServiceActivity` (not `FlutterActivity`) | `android/app/src/main/kotlin/.../MainActivity.kt` | Already done. Keep it that way. |
| `audio_service` plugin ships its `<service>` + `<receiver>` classes but does NOT auto-declare them in its plugin manifest | `android/app/src/main/AndroidManifest.xml` | Already declared. Same applies to any new media plugin — check its manifest. |
| **AGP resource shrinker strips drawables referenced only via `Resources.getIdentifier()`.** Manifested as `IllegalArgumentException: Invalid notification (no valid small icon)` on first release-build playback. | `android/app/src/main/res/raw/keep.xml` | `tools:keep="@drawable/ic_notification"` pins it. Any future drawable that's only looked up reflectively needs the same pin. |
| media_kit_video's `Video` widget defaults to `AdaptiveVideoControls`, which paints its own play / scrubber overlay on top of yours | `lib/features/player/presentation/widgets/full_player.dart` | Always pass `controls: (_) => const SizedBox.shrink()`. |
| `Video` widget auto-pauses on `AppLifecycleState.paused` (kills background audio for the on-screen player) | same file | Pass `pauseUponEnteringBackgroundMode: false`. |
| Notification small icon **must** be a white-on-transparent drawable; coloured mipmaps are silently rejected on Android 5+ | `android/app/src/main/res/drawable/ic_notification.xml` | Already a vector drawable. Keep it. |
| `SystemChrome.setPreferredOrientations` on iOS only declares allowed orientations — it does NOT physically rotate | `lib/features/player/presentation/widgets/full_player.dart` | We also invoke the `yt_offline/orientation` MethodChannel; AppDelegate uses `requestGeometryUpdate` on iOS 16+. |
| Same `Video` widget across portrait↔landscape layouts requires a shared `GlobalKey` to avoid remounting (which stalls libmpv on iOS) | same file | `FullPlayer.videoKey` is the static GlobalKey. Reuse it. |
| **`load()` returning `const []` on absent JSON store will silently break the first write** when callers do `.add()` on the result. Bug already bit the watch-history log. | any new `core/storage/*_store.dart` | Return `<T>[]` (growable) instead of `const []`. |
| Oppo / ColorOS background killer kills the foreground service anyway; users need to whitelist the app in battery settings | n/a — runtime quirk | Document for users; nothing to do in code. |
| Corporate SSL inspection (Zscaler etc.) breaks Gradle + Git on Windows. Workarounds already in place. | `android/gradle.properties` (Windows-ROOT trust store) and global git config (`http.sslBackend schannel`) | If a new dev's git push / Gradle fetch fails with PKIX errors, those are the two fixes. |
| Disk space — Flutter builds need ~5–10 GB transient. Project moved from `C:\Users\user\Desktop\AI talk\yt_offline` to `D:\yt_offline` for this reason. | n/a | Keep project on a drive with > 10 GB free. |
| Analyzer 7.6 has a `visitDotShorthandInvocation` bug that crashes Freezed | n/a | We stripped Freezed + all build_runner — DO NOT reintroduce. Hand-rolled value classes with `copyWith` are the convention. |
| `youtube_explode_dart` can break overnight when YouTube changes its internal API | `test/search_integration_test.dart` | Canary test hits real YouTube. Bump the package version first when search starts failing. |
| Adaptive streams (>720p) require ffmpeg muxing | `lib/features/download/data/datasources/youtube_stream_datasource.dart` | We only download from `manifest.muxed`. Don't try to combine audio/video without ffmpeg. |

---

## 6. Architecture in one screen

(Full version in README.md §Architecture.)

```
Presentation (Flutter widgets, Riverpod providers + state)
       ↓ depends on
Domain (pure Dart: entities, repository interfaces, use cases,
        Result<T> + sealed Failure)
       ↑ implemented by
Data (3rd-party SDKs: youtube_explode_dart, background_downloader,
      media_kit, audio_service, file I/O)
```

Each feature lives under `lib/features/<name>/{data,domain,presentation}/`.
Cross-cutting infra lives under `lib/core/`:

- `core/errors/failure.dart` — sealed `Failure` hierarchy
- `core/result/result.dart` — `sealed Result<T> = Ok<T> | Err<T>`
- `core/storage/` — `MediaStorage`, `VideoMetadataStore`, `CategoryStore`,
  `PreferencesStore`, `WatchHistoryStore`, `StorageInspector`
- `core/i18n/` — `strings.dart` (the `S` class) +
  `settings_providers.dart`
- `core/router/app_router.dart` — go_router config with Settings
  sub-routes (`subtitles`, `storage`, `history`)
- `core/shell/main_shell.dart` — bottom nav + mini player
- `core/share/share_intake.dart` — incoming intent / URL listener
- `core/pip/pip_controller.dart` — Android PiP entry point

**No code generation.** freezed / build_runner / riverpod_generator
are explicitly out — every value class has hand-rolled `copyWith`,
`==`, `hashCode`. Stay consistent.

---

## 7. Build / run quick reference

```sh
cd D:\yt_offline
flutter pub get
flutter analyze                          # MUST be clean before commit
flutter test test/search_integration_test.dart  # YouTube API canary

# Release install on the test device
flutter build apk --release
flutter install --release -d 3adac2ea
adb -s 3adac2ea shell am start -n com.example.ytoffline.yt_offline/.MainActivity

# Or attached run with hot reload
flutter run -d <id>
```

iOS not yet built in this environment (no Mac). Setup once on a Mac:
`cd ios && pod install`; then open `Runner.xcworkspace` in Xcode.

---

## 8. Memories at the top of the next session

These auto-load from
`C:\Users\user\.claude\projects\d--yt-offline\memory\`:

- `feedback_commit_push_each_task.md` — one commit per feature, push
  immediately
- `feedback_cross_platform_required.md` — Android + iOS both required
  for every change
