# Handover

Snapshot for a new session / dev picking this up. Pair with
[`README.md`](README.md) — that one explains *what the app is and how it's
built*. This one explains *what's queued, what's tricky, and the
non-negotiables*.

---

## 1. Where we are right now

Branch: `main`. Latest commit: `76a4d9d` — i18n now localises the
`Uncategorized` sentinel at every display site.

The app is feature-rich already (search, download, library w/ categories
& drag-reorder, full + mini + landscape player, sleep timer, playback
speed, resume position, lock-screen media controls, background audio,
i18n en/zh_TW, light/dark theme). See README §Features for the full list.

Recent commit log skim (most → least recent):

```
76a4d9d  i18n: localise Uncategorized everywhere
2b084ef  Theme switcher in Settings
ea60267  i18n setup + en/zh_TW + Language picker
1b5ff11  Library "collapse / expand all" toggle
921c122  Settings tab with version readout
85e60fe  Share GlobalKey for Video widget across rotation
1d4dac6  Fix Swift compile: applicationRegistrar.messenger()
af95165  iOS Podfile.lock sync
0250eb4  Auto-sync playback queue with library list
41bea93  Force iOS orientation via native MethodChannel
8cac5b9  Suppress media_kit built-in controls + wire fullscreen rotation
0413f9a  Wire audio_service Android host pieces (MainActivity + manifest)
a4dadb8  Landscape fullscreen player with overlay controls
7559668  Swap flutter_background → audio_service
33d30b7  Persist + restore playback position
```

---

## 2. Non-negotiable rules

These are durable instructions from the user. They apply to every change
the next session ships.

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
- Native code? Implement **both** sides before merging. Existing examples
  are good references:
  - `android/app/src/main/kotlin/.../MainActivity.kt` extends
    `AudioServiceActivity` for audio_service init.
  - `android/app/src/main/AndroidManifest.xml` declares the audio_service
    `<service>` and `<receiver>` (plugins ship the classes but don't
    auto-register them — the same trap got us twice).
  - `ios/Runner/AppDelegate.swift` registers a MethodChannel for forced
    orientation: `requestGeometryUpdate` on iOS 16+, KVC trick on older.
  - `ios/Runner/Info.plist` lists `UIBackgroundModes=audio` for
    background audio, and supports landscape orientations.
- Guard platform-specific Dart code with
  `defaultTargetPlatform == TargetPlatform.iOS` etc.

---

## 3. Backlog — 8 features to build

Listed in the order the user named them. My recommended ship order is at
the end of each (lowest cost first vs. impact).

For each: **what it does**, **files / dirs likely touched**, **sketch**,
**cross-platform notes**, **acceptance test**.

### Backlog 1 — Search filters
**What:** Add filters to YouTube search — duration range, upload date
window, sort by (relevance / view count / upload date / rating).

**Files:**
- `lib/features/search/data/datasources/youtube_search_remote_datasource.dart`
  — pass `SearchFilter` into `_yt.search.search(query, filter: ...)`.
- `lib/features/search/domain/repositories/search_repository.dart` —
  search signature takes filter object.
- `lib/features/search/domain/entities/` — new `SearchFilters` value class
  (duration / uploadDate / sort enums).
- `lib/features/search/presentation/widgets/search_filters_sheet.dart` —
  new bottom sheet picker.
- AppBar gets a filter icon next to the search icon.
- `lib/core/i18n/strings.dart` — labels.

**Cross-platform:** pure Dart. `youtube_explode_dart`'s `SearchFilter` is
the same on both.

**Acceptance:** open filter sheet, pick "Long (> 20 min) / This year /
view count desc" → results obey the filter; sheet remembers last selection
within the session.

**Cost:** ~1 hr.

### Backlog 2 — Storage management page
**What:** Settings → "Storage" subpage shows total used, per-category
breakdown, biggest videos, and a "Free X by deleting watched" action.

**Files:**
- `lib/features/settings/presentation/screens/storage_screen.dart` (new).
- `lib/features/settings/presentation/screens/settings_screen.dart` —
  add a ListTile that pushes the storage screen.
- `lib/core/router/app_router.dart` — register the sub-route under
  Settings branch.
- `lib/core/storage/storage_inspector.dart` (new) — utility that walks
  `<documents>/videos/` and returns sizes grouped by category, plus the
  list of fully-watched videos (use `meta.watchedFraction >=
  finishedThreshold`).
- `lib/core/i18n/strings.dart` — labels.

**Cross-platform:** `path_provider` + `dart:io` directory scan. Identical.

**Acceptance:** open Storage page → see "Used: 2.3 GB across 47 videos",
per-category bar chart or list, a "Delete watched (4 videos, 320 MB)"
button that runs `LibraryRepository.delete` for each.

**Cost:** ~1.5 hr.

### Backlog 3 — Accept external share
**What:** When user taps "Share" on a YouTube link in another app, our
app appears in the share sheet. Receiving the URL pre-fills search +
optionally goes straight to the category picker.

**Files:**
- **Android**: `android/app/src/main/AndroidManifest.xml` — add an
  `<intent-filter>` to `MainActivity` for `android.intent.action.SEND`
  with `text/plain` MIME, plus another `VIEW` filter for
  `https://*.youtube.com/*` deep links.
- **iOS**: a new Share Extension target in Xcode is the heavy path; the
  lighter path is to register a custom URL scheme + universal links via
  `CFBundleURLTypes` + `Associated Domains`. Start with the lighter one
  (URL scheme); add the share extension later if needed.
- `receive_sharing_intent: ^...` pub package (check current version,
  pub.dev shows both platforms) — listens for incoming intents/URLs.
- `lib/main.dart` — register listener; on URL receipt, parse the videoId,
  navigate to `/search?prefill=...` or directly open the category picker.

**Cross-platform:** the plugin abstracts the per-platform glue. iOS path
needs Info.plist URL scheme entries.

**Acceptance:** Android: open YouTube app, tap Share, pick yt_offline →
app opens with the URL pre-filled. iOS (when built): same flow via share
sheet OR universal link tap.

**Cost:** ~2 hr Android, +1 hr to wire iOS share extension cleanly.

### Backlog 4 — Picture-in-Picture
**What:** While playing a video, pressing Home shrinks the player to a
floating window. Standard on Android 8+ and iOS 14+.

**Files:**
- **Android**: `android/app/src/main/AndroidManifest.xml` — add
  `android:supportsPictureInPicture="true"` to MainActivity.
- **Android**: `MainActivity.kt` — override `onUserLeaveHint()` (and the
  newer `onPictureInPictureModeChanged`) to call
  `enterPictureInPictureMode(PictureInPictureParams)`.
- **iOS**: `AVPictureInPictureController` integration — likely requires a
  platform channel or use the `pip_view` / `floating` pub packages.
- A MethodChannel from Flutter ↔ native to request PiP on user gesture
  (e.g. an icon in the FullPlayer landscape overlay).
- `lib/features/player/presentation/widgets/full_player.dart` — add a
  PiP icon button.
- Check: media_kit's Video widget plays nicely with surfaces resized to
  PiP dimensions; expect to test.

**Cross-platform:** Android part is straightforward. iOS PiP for arbitrary
video surfaces is harder than media controls — needs an
`AVPictureInPictureController` wired to an `AVPlayerLayer`, which media_kit
doesn't expose directly. Easiest iOS route: use the `floating` package on
pub.dev (verify it still supports media_kit-style surfaces).

**Acceptance:** play a video, press the home button → window shrinks to a
PiP overlay, audio + video keep going. Tap the floating window → app
expands back.

**Cost:** ~2 hr Android, ~4 hr iOS (custom AVPlayerLayer bridge or
package wrangling).

### Backlog 5 — Subtitle styling
**What:** Settings page section: font size (small / medium / large /
custom), color, background opacity, vertical position. Applied to all
playback.

**Files:**
- `lib/core/storage/preferences_store.dart` + `AppPreferences` — extend
  with `subtitleFontSize`, `subtitleColor`, `subtitleBackgroundAlpha`,
  `subtitlePosition`.
- `lib/features/player/presentation/providers/playback_providers.dart`
  — after `_openCurrent` (or in a ref.listen on preferences), apply the
  styling via `player.setProperty('sub-font-size', ...)`,
  `'sub-color'`, `'sub-back-color'`, `'sub-pos'`, etc. Full mpv property
  list is in libmpv docs.
- `lib/features/settings/presentation/screens/subtitle_settings_screen.dart`
  (new) with live-preview if feasible.
- `lib/core/i18n/strings.dart` — labels.

**Cross-platform:** media_kit's `setProperty` works identically on Android
and iOS — libmpv handles rendering.

**Acceptance:** open a video with subtitles → tweak font size in Settings
→ the rendered subtitle reflects the change without restarting playback.

**Cost:** ~1.5 hr.

### Backlog 6 — A-B segment loop
**What:** Inside the player, two new buttons: "Set A" and "Set B". Once
both set, playback loops between A and B until cleared. Survives queue
changes? Probably scoped to current video.

**Files:**
- `lib/features/player/presentation/state/playback_state.dart` — add
  `Duration? loopA`, `Duration? loopB`.
- `lib/features/player/presentation/providers/playback_providers.dart`
  — listen to the position stream; when position > loopB and both set,
  `player.seek(loopA)`. Add `setLoopA(Duration?)` / `setLoopB(Duration?)`
  / `clearLoopAB()` methods.
- `lib/features/player/presentation/widgets/full_player.dart` — add two
  small marker buttons under the scrubber + a visual indicator on the
  scrubber bar showing the loop range.
- Optionally: persist last AB per video in `VideoMetadata` if "remembered
  loops" is desired (skip for v1).
- `lib/core/i18n/strings.dart` — labels.

**Cross-platform:** pure Dart + media_kit. Identical.

**Acceptance:** play a video, set A at 0:30, set B at 0:45 → playback
loops 0:30↔0:45 indefinitely. Tap Clear → resumes linear playback.

**Cost:** ~1.5 hr.

### Backlog 7 — Gesture controls in landscape player
**What:** Standard video-app swipe affordances inside landscape fullscreen:
- swipe **left half vertically** → brightness
- swipe **right half vertically** → volume
- **horizontal swipe** anywhere → seek (drag thumb appears showing the
  target time)
- **double-tap left third** → seek -10s; **right third** → +10s

**Files:**
- `lib/features/player/presentation/widgets/full_player.dart` — wrap the
  landscape Video widget in a `GestureDetector` with onVerticalDragUpdate
  + onHorizontalDragUpdate + onDoubleTapDown handlers.
- Brightness: `screen_brightness: ^...` pub package (cross-platform).
- Volume: platform channel call. There's `volume_controller: ^...` or
  `flutter_volume_controller: ^...` (verify both platforms supported).
- Custom overlay (`Stack`) for the temporary indicator widgets that fade
  in during the gesture and out 1s after release.

**Cross-platform:** both packages support Android and iOS. iOS volume
control via private API is risky — check current package docs.

**Acceptance:** in landscape, swipe up on right half → volume rises (+
overlay shows level); swipe left on screen → seek -X seconds (+ overlay
shows target time); release → playback continues at the new position.

**Cost:** ~2 hr.

### Backlog 8 — Watch history
**What:** Tracks every play start with timestamp + final position. Settings
or a dedicated History tab in the bottom nav. "Re-watch" jumps straight in.

**Files:**
- `lib/core/storage/watch_history_store.dart` (new) — append-only JSON
  log at `<documents>/watch_history.json`. Each entry: `{videoId, startedAt,
  endedAt?, durationWatched}`.
- `lib/features/history/` (new feature folder, follow the same
  domain/data/presentation split as the other features).
- Hook into `PlaybackController._openCurrent` (start entry) and
  `_persistPosition` / `_onTrackCompleted` (close out the entry).
- `lib/features/history/presentation/screens/history_screen.dart` —
  reverse-chronological list with thumbnails + "played up to 5:23".
- `lib/core/router/app_router.dart` — add as a route. **Question for the
  user**: should this be a 4th bottom-nav tab, or a sub-screen reached
  from Settings? Default to Settings sub-screen to keep the nav clean.
- Provider for the history list + a clear-all action.
- `lib/core/i18n/strings.dart` — labels.

**Cross-platform:** pure Dart + filesystem. Identical.

**Acceptance:** play 3 videos in a row → open History → see all 3 in
reverse order, each with thumbnail / title / "played up to N:NN". Tap a
row → resumes (uses existing resume-position machinery).

**Cost:** ~2 hr.

---

## 4. Recommended ship order

Lowest cost / fastest payoff first, so each commit ships visible value:

1. **Search filters** (1 hr) — completes the search experience
2. **Subtitle styling** (1.5 hr) — quick win for the language-learning
   use case
3. **A-B segment loop** (1.5 hr) — same use case, similar cost
4. **Storage management** (1.5 hr) — power-user surface
5. **Watch history** (2 hr) — adds a new screen + persistence pattern
6. **Gesture controls** (2 hr) — needs UX polish + two pub packages
7. **External share** (3 hr) — Android fast, iOS slower
8. **Picture-in-Picture** (6 hr total) — iOS side is the biggest unknown

---

## 5. Existing traps to avoid (learned the hard way)

These all bit us already. Don't waste cycles re-discovering them.

| Trap | Where | Fix |
|---|---|---|
| `audio_service` requires `MainActivity` to extend `AudioServiceActivity` (not `FlutterActivity`) | `android/app/src/main/kotlin/.../MainActivity.kt` | Already done. Keep it that way. |
| `audio_service` plugin ships its `<service>` + `<receiver>` classes but does NOT auto-declare them in its plugin manifest | `android/app/src/main/AndroidManifest.xml` | Already declared. Same applies to any new media plugin — check its manifest. |
| media_kit_video's `Video` widget defaults to `AdaptiveVideoControls`, which paints its own play / scrubber overlay on top of yours | `lib/features/player/presentation/widgets/full_player.dart` | Always pass `controls: (_) => const SizedBox.shrink()`. |
| `Video` widget auto-pauses on `AppLifecycleState.paused` (kills background audio for the on-screen player) | same file | Pass `pauseUponEnteringBackgroundMode: false`. |
| Notification small icon **must** be a white-on-transparent drawable; coloured mipmaps are silently rejected on Android 5+ | `android/app/src/main/res/drawable/ic_notification.xml` | Already a vector drawable. Keep it. |
| `SystemChrome.setPreferredOrientations` on iOS only declares allowed orientations — it does NOT physically rotate | `lib/features/player/presentation/widgets/full_player.dart` | We also invoke the `yt_offline/orientation` MethodChannel; AppDelegate uses `requestGeometryUpdate` on iOS 16+. |
| Same `Video` widget across portrait↔landscape layouts requires a shared `GlobalKey` to avoid remounting (which stalls libmpv on iOS) | same file | `FullPlayer.videoKey` is the static GlobalKey. Reuse it. |
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
  `PreferencesStore`
- `core/i18n/` — `strings.dart` (the `S` class) +
  `settings_providers.dart`
- `core/router/app_router.dart` — go_router config
- `core/shell/main_shell.dart` — bottom nav + mini player

**No code generation.** freezed / build_runner / riverpod_generator are
explicitly out — every value class has hand-rolled `copyWith`, `==`,
`hashCode`. Adds ~5 lines per class, removes one class of build-time
breakage. Stay consistent.

---

## 7. Build / run quick reference

```sh
cd D:\yt_offline
flutter pub get
flutter analyze                          # MUST be clean before commit
flutter test test/search_integration_test.dart  # YouTube API canary

# Run on device
flutter devices                          # confirm device id
flutter build apk --debug
flutter install --debug -d <id>
adb -s <id> shell am start -n com.example.ytoffline.yt_offline/.MainActivity

# Or attached run with hot reload
flutter run -d <id>
```

Android-only one-time fixes for the corporate SSL gotcha:
- `android/gradle.properties` already has
  `-Djavax.net.ssl.trustStoreType=Windows-ROOT`
- `git config --global http.sslBackend schannel`

iOS not yet built in this environment (no Mac). Setup once on a Mac:
`cd ios && pod install`; then open `Runner.xcworkspace` in Xcode.

---

## 8. Where to ask the user

Open questions worth surfacing before going deep:

- **Watch History placement** — bottom nav 4th tab, or Settings sub-screen?
- **External share preference on iOS** — full Share Extension target, or
  just URL scheme + universal links? (much cheaper)
- **AB loop persistence** — remembered per video, or session-scoped only?
- **Storage management cleanup actions** — auto-delete watched older than
  N days a future feature, or out of scope for this iteration?
- **Subtitle styling preview** — live in player, or static preview text
  in Settings?

---

## 9. Memories at the top of the next session

These should auto-load from
`C:\Users\user\.claude\projects\c--Users-user-Desktop-AI-talk\memory\`:

- `feedback_commit_push_each_task.md` — one commit per feature, push
  immediately
- `feedback_cross_platform_required.md` — Android + iOS both required for
  every change

If they don't surface for some reason, re-read both before starting.
