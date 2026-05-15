# yt_offline

A Flutter app that searches YouTube, downloads videos with subtitles,
and plays them back offline organised by user-defined categories. Designed
for Android (works on API 21+, tested on 7.1.1). The codebase is structured
as a textbook example of **Clean Architecture + Riverpod** on Flutter.

> **Legal note** — this project bypasses the YouTube Data API by extracting
> stream URLs directly. That violates YouTube's Terms of Service, and Apple
> App Store / Google Play **will reject it**. Ship to internal users only:
> APK side-load, TestFlight, or a private MDM.

---

## Features

- Search YouTube with paginated results (auto-loads more on scroll)
- Per-video category chosen at download time
- Subtitle extraction → bundled SRT next to the video
- Resumable / pausable / cancellable downloads via `background_downloader`
- "In progress" tray in Library with Pause / Resume / Cancel / Retry / Dismiss
- Library grouped by category, collapsible sections
- Drag tile to reorder within a category
- Drag tile onto a category header to move it
- Long-press to enter multi-select → batch move to another category
- Swipe a tile left → red background reveals delete icon
- Add / rename / delete categories (delete reroutes contents to Uncategorized)
- Search history with fuzzy filter; appears only while the search box is focused
- Single + global delete on history entries
- Skip-on-duplicate: tapping an already-downloaded video shows a SnackBar,
  no redundant fetch
- Global mini player bar above the bottom nav
- Full player screen with queue, loop (off / one / all), shuffle, scrubber
- Real background audio playback via foreground service (`flutter_background`)
- Animated equalizer indicator on the currently-playing Library tile

---

## Tech stack

| Concern | Choice | Why |
|---|---|---|
| Framework | Flutter 3.41.x, Dart 3.11.x | One codebase, native UI |
| State + DI | `flutter_riverpod` 2.6 (no codegen) | DI = providers; no `get_it` |
| Routing | `go_router` 14 + `StatefulShellRoute.indexedStack` | Tabs that survive navigation |
| YouTube | `youtube_explode_dart` 2.5 | Search + stream manifest + captions |
| HTTP | `dio` 5 | Future use; not in hot paths |
| Downloads | `background_downloader` 8 | Resumable, queueable, background-safe |
| Player | `media_kit` 1 + `media_kit_video` 1 + `media_kit_libs_video` 1 | MPV under the hood; external subtitles |
| Background audio | `flutter_background` 1 | Foreground service to defeat Android process kill |
| Wakelock | `wakelock_plus` 1 | Hold CPU while playing |
| Filesystem | `path_provider` + `path` | App docs dir for all media |
| Misc | `intl`, `collection` | — |

**No code generation.** `freezed` / `riverpod_generator` / `json_serializable`
were deliberately removed after we hit
[analyzer 7.6 visitDotShorthandInvocation bug](https://github.com/dart-lang/sdk/issues)
on Dart 3.11. All value classes are hand-rolled with explicit `copyWith`,
`==`, `hashCode`. This trades ~100 lines of boilerplate for zero build_runner
runs and immunity to future analyzer/freezed version skew.

---

## Architecture

Clean Architecture with a **feature-first** folder layout. The dependency
rule is one-way: **Presentation → Domain ← Data**. Domain is pure Dart with
no Flutter/3rd-party imports.

```
                    +-----------------+
                    |  Presentation   |   widgets, screens, Riverpod
                    |   (Flutter UI)  |   providers, state classes
                    +--------+--------+
                             | depends on
                             v
                    +-----------------+
                    |     Domain      |   entities, repository INTERFACES,
                    |   (pure Dart)   |   use cases, Result/Failure
                    +-----------------+
                             ^ implements
                             |
                    +--------+--------+
                    |      Data       |   datasources, repository IMPLS,
                    | (3rd-party SDKs)|   DTO mappers, storage adapters
                    +-----------------+
```

### Feature inventory

Each feature lives under `lib/features/<name>/` with its own `data/`,
`domain/`, `presentation/`:

| Feature | Responsibility |
|---|---|
| `search` | Query YouTube, paginate, search history |
| `download` | Resolve streams + captions, manage the BG queue, surface jobs |
| `library` | List downloaded videos, CRUD categories, reorder, move |
| `player` | Global playback controller, mini player, full player screen |

Cross-feature infrastructure lives in `lib/core/`:

| Folder | Purpose |
|---|---|
| `core/errors/failure.dart` | `sealed class Failure` hierarchy (NetworkFailure, AlreadyDownloadedFailure, etc.) |
| `core/result/result.dart` | `sealed class Result<T>` = `Ok<T>` \| `Err<T>` |
| `core/storage/` | `MediaStorage`, `VideoMetadataStore`, `CategoryStore` — shared persistence |
| `core/router/` | `go_router` config; `StatefulShellRoute` for Search/Library tabs |
| `core/shell/main_shell.dart` | Bottom nav + mini player bar |

---

## Key design patterns

### `Result<T>` instead of exceptions across layer boundaries

Repositories return `Future<Result<T>>` so callers handle failure
at the type level. The `Result.when` helper does the pattern match:

```dart
final result = await repo.search(query);
state = result.when(
  ok: (page) => SearchLoaded(videos: page.items, hasMore: page.hasMore),
  err: (f) => SearchError(f.message),
);
```

### Sealed unions for screen state

Without freezed, state unions are written as:

```dart
sealed class SearchState { const SearchState(); }
class SearchInitial extends SearchState { const SearchInitial(); }
class SearchLoading extends SearchState { const SearchLoading(); }
class SearchLoaded extends SearchState {
  final List<VideoSummary> videos;
  final bool hasMore;
  final bool loadingMore;
  // + copyWith
}
class SearchError extends SearchState {
  final String message;
  const SearchError(this.message);
}
```

Dart 3 `switch` expressions exhaustively match sealed subtypes.

### Repository owns the cursor

`SearchRepositoryImpl` keeps the `VideoSearchList` from
`youtube_explode_dart` as an internal cursor. The domain layer only sees a
`VideoPage(items, hasMore)`. UI never knows pagination is cursor-based.

### Two-phase download with synthetic job IDs

`enqueue()` is split:

- **Phase A** (resolve stream + captions): synchronous insert into the
  jobs map with a synthetic `prep:<videoId>:<ts>` key so the UI can show
  a "preparing" entry with a Cancel button.
- **Phase B** (hand off to `background_downloader`): on success, re-key
  the job to the real `taskId` returned by the BG plugin. Status updates
  from the BG stream find the right job by `taskId`.

The repo also tracks `_cancelRequested: Set<String>` — Cancel during
Phase A flags the prep id; we check the flag after `_stream.resolve()`
returns and abort before enqueueing the BG task.

### Single global `PlaybackController`

`playbackControllerProvider` is a `NotifierProvider` at the root scope.
The `Player` lives inside it; navigating away from the player screen does
not dispose it. The mini player widget watches the same provider, so it
appears across tabs whenever `state.current != null`.

### Drag-and-drop reordering / recategorizing

Each Library tile is wrapped twice:

- Inside: `Dismissible` (swipe left → delete)
- Middle: `LongPressDraggable<VideoMetadata>` (long-press lift)
- Outside: `DragTarget<VideoMetadata>` (other tiles drop here → insert above)

Section headers are `DragTarget<VideoMetadata>` — drop a tile on a header
to append to that category. Reordering writes a per-category `position`
field on `VideoMetadata` and rewrites the affected files.

---

## Project structure

```
yt_offline/
├── android/                # Flutter Android shell + manifest
├── ios/                    # untested
├── lib/
│   ├── main.dart           # ProviderScope + MediaKit.ensureInitialized
│   ├── app.dart            # MaterialApp.router + initializer gate
│   ├── core/
│   │   ├── errors/failure.dart
│   │   ├── result/result.dart
│   │   ├── router/app_router.dart
│   │   ├── shell/main_shell.dart
│   │   └── storage/
│   │       ├── media_storage.dart      # paths under app docs dir
│   │       ├── video_metadata.dart     # DTO + toJson/fromJson + copyWith
│   │       ├── video_metadata_store.dart
│   │       └── category_store.dart
│   └── features/
│       ├── search/
│       │   ├── data/
│       │   │   ├── datasources/
│       │   │   │   ├── youtube_search_remote_datasource.dart  # cursor
│       │   │   │   └── search_history_store.dart
│       │   │   ├── mappers/video_summary_mapper.dart
│       │   │   └── repositories/search_repository_impl.dart
│       │   ├── domain/
│       │   │   ├── entities/video_summary.dart, video_page.dart
│       │   │   ├── repositories/search_repository.dart
│       │   │   └── usecases/search_videos.dart, load_more_videos.dart
│       │   └── presentation/
│       │       ├── providers/   # search_providers, search_history_provider
│       │       ├── screens/search_screen.dart
│       │       ├── state/search_state.dart
│       │       └── widgets/     # VideoCard, CategoryPickerSheet
│       ├── download/
│       │   ├── data/datasources/youtube_stream_datasource.dart         # stream URL + SRT
│       │   ├── data/datasources/background_download_datasource.dart    # FileDownloader wrap
│       │   ├── data/repositories/download_repository_impl.dart
│       │   ├── domain/entities/download_status.dart, download_job.dart
│       │   ├── domain/repositories/download_repository.dart
│       │   ├── domain/usecases/download_video.dart
│       │   └── presentation/providers/download_providers.dart
│       ├── library/
│       │   ├── data/repositories/library_repository_impl.dart
│       │   ├── domain/repositories/library_repository.dart
│       │   └── presentation/
│       │       ├── providers/library_providers.dart
│       │       ├── screens/library_screen.dart      # the big one
│       │       └── widgets/
│       │           ├── downloaded_video_tile.dart
│       │           └── equalizer_indicator.dart
│       └── player/
│           └── presentation/
│               ├── providers/playback_providers.dart   # PlaybackController + bg service
│               ├── screens/player_screen.dart
│               ├── state/playback_state.dart           # LoopMode, queue, etc
│               └── widgets/mini_player_bar.dart
├── test/
│   ├── search_integration_test.dart    # hits real YouTube
│   └── widget_test.dart
├── analysis_options.yaml   # strict-casts/strict-inference/strict-raw-types
└── pubspec.yaml
```

### On-disk layout (Android: `getApplicationDocumentsDirectory()`)

```
<documents>/
├── videos/
│   ├── <videoId>.mp4
│   ├── <videoId>.srt      # optional, English-preferred
│   └── <videoId>.json     # VideoMetadata
├── categories.json        # user-created empty categories
└── search_history.json    # max 50 entries, MRU
```

---

## Setup

### Prerequisites

- Flutter 3.41.x stable
- Android SDK + a connected Android device (or emulator) for testing
- Optional: Visual Studio Build Tools for Windows desktop runs

### One-time environment fixes (Windows + corporate networks)

These are non-obvious and bit us hard early in development. **Apply both
if you're behind an SSL inspection proxy** (Zscaler, McAfee Web Gateway,
etc.):

1. **Gradle → Windows certificate store**. Already done in this repo:
   `android/gradle.properties` contains
   `-Djavax.net.ssl.trustStoreType=Windows-ROOT`.

2. **Git → Windows certificate store** (run once globally):
   ```sh
   git config --global http.sslBackend schannel
   ```

3. **Don't put the project under `C:\…\AI talk\` or any path with a
   space**. Flutter / Gradle / sub-processes mostly handle spaces, but
   PowerShell quoting around the path causes intermittent denials in
   automation. The project is happy at `D:\yt_offline`.

### Install dependencies

```sh
cd D:\yt_offline
flutter pub get
```

### Run on a device

```sh
flutter devices                          # confirm your device is listed
flutter run -d <id>                      # attached run with hot reload

# Or build + side-load
flutter build apk --debug
flutter install --debug -d <id>
adb -s <id> shell am start -n com.example.ytoffline.yt_offline/.MainActivity
```

First Android build takes 2–10 min (Gradle + native libs). Subsequent
builds are 10–20 s.

### Verify without a device

```sh
flutter analyze                          # zero issues expected
flutter test test/search_integration_test.dart   # hits real YouTube
```

---

## Known issues + gotchas

These caused real-world failures during development. Read them before
debugging similar symptoms.

### `flutter_background` doesn't declare its own service

The plugin ships `IsolateHolderService` in Kotlin but its
`AndroidManifest.xml` only declares permissions, **not** the `<service>`.
We added it manually in
[`android/app/src/main/AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml).
Without that declaration, `startForegroundService` is a silent no-op and
audio dies the moment the app goes to background.

### `media_kit_video` auto-pauses on activity lifecycle

The `Video` widget has `pauseUponEnteringBackgroundMode: true` by default
and calls `player.pause()` on `AppLifecycleState.paused`. The fix is in
[`player_screen.dart`](lib/features/player/presentation/screens/player_screen.dart):
explicitly pass `false`.

### Notification small icon must be `drawable/`, not `mipmap/`

Android silently hides notification icons that aren't white-on-transparent.
Use [`res/drawable/ic_notification.xml`](android/app/src/main/res/drawable/ic_notification.xml),
not `mipmap/ic_launcher`.

### Oppo / ColorOS still kills background even with foreground service

`dumpsys activity services` showed `isForeground=true` with a notification
attached, yet audio stopped. The fix is in **device settings**: Battery →
App battery management → app → allow background activity. See
[dontkillmyapp.com/oppo](https://dontkillmyapp.com/oppo) for the per-OEM
matrix.

### `youtube_explode_dart` may break overnight

YouTube's internal API is the surface this library calls. When it changes
shape (often during YouTube experiments), search or stream resolution can
return wrong types or fail. Bump `youtube_explode_dart` first; the
integration test (`test/search_integration_test.dart`) is the canonical
canary.

### Adaptive streams are not muxed

The download path only consumes `manifest.muxed` (max ~720p). Higher
qualities live in separate `manifest.video` and `manifest.audio` streams,
which need `ffmpeg` to combine. Combining client-side is out of scope.

### Disk space

A full Flutter build needs ~5–10 GB transient under `.dart_tool/` and
`build/`. If you're under 5 GB free on the project drive, builds hang
mid-write with cryptic file-handle errors. `flutter clean` reclaims
most of it.

---

## What's not done yet

- iOS — never built / tested; manifest changes for background audio are
  Android-only
- Adaptive (>720p) downloads (needs on-device muxing)
- Real MediaSession on the lock screen / media controls
- Settings screen (quality preference, default category, etc.)
- Tests beyond the search integration smoke test
- Localization (Traditional Chinese strings would be a natural first add)
- Sharing / export / import library metadata

---

## Development notes

- Strict lints are on: `analysis_options.yaml` enables `strict-casts`,
  `strict-inference`, `strict-raw-types`, plus `require_trailing_commas`,
  `prefer_single_quotes`, `avoid_print`, `unawaited_futures`.
  Run `flutter analyze` before every commit — it should be clean.
- The integration test in `test/search_integration_test.dart` hits real
  YouTube. It catches `youtube_explode_dart` going stale.
- No CI configured. If you add one, run `flutter analyze` + that
  integration test as the bare minimum.
- Commit style: subject in imperative present, body explains the *why*.
  See `git log` for the established voice.
