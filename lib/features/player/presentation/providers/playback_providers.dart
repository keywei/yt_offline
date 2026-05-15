import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/i18n/settings_providers.dart';
import '../../../../core/storage/preferences_store.dart';
import '../../../../core/storage/video_metadata.dart';
import '../../../../core/storage/watch_history_store.dart';
import '../../../../main.dart' show mediaSessionHandler;
import '../../../download/presentation/providers/download_providers.dart';
import '../../../history/presentation/providers/history_providers.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../state/playback_state.dart';

/// Long-lived [Player] + [VideoController]. Lives in the root ProviderScope
/// so audio survives screen navigation. Background playback is handled by
/// `audio_service` (see `MediaSessionHandler`): it runs the foreground
/// service on Android and configures AVAudioSession on iOS, and surfaces
/// lock-screen / notification / headset / CarPlay controls on both.
class PlaybackController extends Notifier<PlaybackState> {
  Player? _player;
  VideoController? _videoController;
  final _subs = <StreamSubscription<dynamic>>[];
  final _random = Random();

  Timer? _sleepFireTimer;
  Timer? _sleepTickTimer;

  /// Throttle for persisting playback position. We save at most every 5s
  /// while playing so the JSON file doesn't get hammered.
  DateTime? _lastPositionSaveAt;
  static const _positionSaveInterval = Duration(seconds: 5);

  Player get player {
    if (_player == null) _ensurePlayer();
    return _player!;
  }

  VideoController get videoController {
    if (_videoController == null) _ensurePlayer();
    return _videoController!;
  }

  void _ensurePlayer() {
    if (_player != null) return;
    _player = _createPlayer();
    // Must be attached BEFORE any player.open() — otherwise libmpv picks the
    // null video output and the texture stays black even after the controller
    // is created later.
    _videoController = VideoController(_player!);
  }

  Player _createPlayer() {
    final p = Player();
    _subs.addAll([
      p.stream.playing.listen((v) {
        state = state.copyWith(isPlaying: v);
        WakelockPlus.toggle(enable: v);
        if (!v) {
          unawaited(_persistPosition(force: true));
        }
        _publishToMediaSession();
      }),
      p.stream.position.listen((d) {
        state = state.copyWith(position: d);
        _enforceABLoop(d);
        unawaited(_persistPosition());
        _publishToMediaSession();
      }),
      p.stream.duration.listen((d) {
        state = state.copyWith(duration: d);
        _publishToMediaSession();
      }),
      p.stream.completed.listen((completed) {
        if (completed) _onTrackCompleted();
      }),
    ]);
    return p;
  }

  @override
  PlaybackState build() {
    // Hook OS-level controls so the lock-screen / notification / headset
    // buttons drive this controller.
    final handler = mediaSessionHandler;
    handler.onPlay = () {
      unawaited(_play());
    };
    handler.onPause = () {
      unawaited(player.pause());
    };
    handler.onNext = () {
      unawaited(next());
    };
    handler.onPrevious = () {
      unawaited(previous());
    };
    handler.onSeek = (Duration pos) {
      unawaited(seek(pos));
    };
    handler.onStop = () {
      unawaited(stop());
    };

    // Auto-sync the queue with the library: whenever a video is added,
    // deleted, renamed, moved or reordered in the playing category, fold
    // the change into the live queue.
    ref.listen<AsyncValue<List<VideoMetadata>>>(
      libraryListProvider,
      (prev, next) {
        next.whenData(_resyncQueueFromLibrary);
      },
    );

    // Live-apply subtitle styling whenever the user changes a value in
    // Settings → Subtitles. _openCurrent re-applies on every open() too.
    ref.listen<AsyncValue<AppPreferences>>(
      appPreferencesProvider,
      (prev, next) {
        next.whenData(_applySubtitleStyle);
      },
    );

    ref.onDispose(() {
      handler.onPlay = null;
      handler.onPause = null;
      handler.onNext = null;
      handler.onPrevious = null;
      handler.onSeek = null;
      handler.onStop = null;
      for (final s in _subs) {
        s.cancel();
      }
      _cancelSleepTimers();
      _player?.dispose();
      WakelockPlus.disable();
    });
    return const PlaybackState();
  }

  // ---- Public API ----

  Future<void> playQueue(List<VideoMetadata> queue, int startIndex) async {
    state = state.copyWith(queue: queue, index: startIndex);
    await _openCurrent();
    await player.play();
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> _play() async {
    if (!state.isPlaying) await player.play();
  }

  Future<void> seek(Duration to) => player.seek(to);

  /// Update playback rate (0.5x .. 2.0x). Persists across track changes via
  /// `_openCurrent` re-applying it after each `player.open`.
  Future<void> setRate(double rate) async {
    final clamped = rate.clamp(0.25, 4.0);
    await player.setRate(clamped);
    state = state.copyWith(playbackRate: clamped);
    _publishToMediaSession();
  }

  Future<void> next() async {
    final n = _pickNext();
    if (n == null) {
      await player.pause();
      return;
    }
    state = state.copyWith(index: n);
    await _openCurrent();
    await player.play();
  }

  Future<void> previous() async {
    if (!state.hasCurrent) return;
    if (state.position > const Duration(seconds: 3)) {
      await player.seek(Duration.zero);
      return;
    }
    final p = state.index - 1;
    if (p < 0) {
      await player.seek(Duration.zero);
      return;
    }
    state = state.copyWith(index: p);
    await _openCurrent();
    await player.play();
  }

  void cycleLoopMode() => state = state.copyWith(loop: state.loop.next);

  void toggleShuffle() => state = state.copyWith(shuffle: !state.shuffle);

  // ---- A-B segment loop ----

  /// Marks the current playback position as A. Pass an explicit [at] to
  /// seed from a scrubber drag instead. If a B point already exists and
  /// the new A is past it, B is cleared so the user can re-pick it.
  void setLoopA([Duration? at]) {
    final point = at ?? state.position;
    final newB = (state.loopB != null && state.loopB! <= point)
        ? null
        : state.loopB;
    state = state.copyWith(loopA: point, loopB: newB);
  }

  void setLoopB([Duration? at]) {
    final point = at ?? state.position;
    // B before A makes no sense — drop the old A so the user can re-pick.
    final newA = (state.loopA != null && state.loopA! >= point)
        ? null
        : state.loopA;
    state = state.copyWith(loopA: newA, loopB: point);
  }

  void clearLoopAB() {
    state = state.copyWith(loopA: null, loopB: null);
  }

  void _enforceABLoop(Duration pos) {
    if (!state.hasActiveABLoop) return;
    if (pos < state.loopB!) return;
    // Use seek directly so we don't trip the same listener recursively
    // before we've cleared position — media_kit's seek will emit a new
    // position which will already be inside the loop window.
    unawaited(player.seek(state.loopA!));
  }

  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    state = state.copyWith(index: index);
    await _openCurrent();
    await player.play();
  }

  /// Replace the queue with a re-sorted / re-categorised list while
  /// keeping the same video playing. Used by Library after a drag-to-
  /// reorder / drag-to-recategorise. No-op if the active video isn't in
  /// the new list (e.g. user moved it to a different category).
  void syncQueue(List<VideoMetadata> newQueue) {
    final activeId = state.current?.id;
    if (activeId == null) return;
    final newIndex = newQueue.indexWhere((v) => v.id == activeId);
    if (newIndex < 0) return;
    state = state.copyWith(queue: newQueue, index: newIndex);
  }

  /// Called whenever [libraryListProvider] emits. Diffs the current category
  /// against the new library snapshot and keeps the queue in sync:
  ///
  /// - new download in same category → added to queue
  /// - sibling deleted              → removed from queue
  /// - sibling moved out / in       → queue grows or shrinks
  /// - reordering                   → queue order updated
  /// - category renamed             → tracked via the active video's new
  ///                                  category name in the fresh list
  /// - **active video deleted**     → advance to the next sibling, or stop
  ///                                  if the category is now empty
  void _resyncQueueFromLibrary(List<VideoMetadata> all) {
    if (!state.hasCurrent) return;
    final activeId = state.current!.id;

    // Look the active track up in the fresh list so a category rename
    // (which rewrites every member's `category`) is followed correctly.
    final freshActive = all.firstWhere(
      (v) => v.id == activeId,
      orElse: () => state.current!,
    );
    final activeCategory = freshActive.category;

    final newQueue = all.where((v) => v.category == activeCategory).toList()
      ..sort((a, b) {
        if (a.position != b.position) return a.position.compareTo(b.position);
        return b.downloadedAt.compareTo(a.downloadedAt);
      });

    final newIndex = newQueue.indexWhere((v) => v.id == activeId);

    if (newIndex >= 0) {
      // Active still present — update queue if order / size changed.
      if (!_queueOrderEquals(newQueue, state.queue)) {
        state = state.copyWith(queue: newQueue, index: newIndex);
      }
      return;
    }

    // Active video has been deleted (or moved to another category by an
    // outside path that didn't go through our move/syncQueue helpers).
    if (newQueue.isEmpty) {
      unawaited(stop());
      return;
    }
    // Fall through to a sibling near where the old item was.
    final fallback = state.index.clamp(0, newQueue.length - 1);
    state = state.copyWith(queue: newQueue, index: fallback);
    unawaited(_openCurrent().then((_) => player.play()));
  }

  bool _queueOrderEquals(List<VideoMetadata> a, List<VideoMetadata> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  // ---- Sleep timer ----

  void setSleepTimer(Duration? duration) {
    _cancelSleepTimers();
    if (duration == null || duration == Duration.zero) {
      state = state.copyWith(
        sleepRemaining: null,
        sleepAtEndOfTrack: false,
      );
      return;
    }
    final fireAt = DateTime.now().add(duration);
    _sleepFireTimer = Timer(duration, () async {
      await player.pause();
      _cancelSleepTimers();
      state = state.copyWith(sleepRemaining: null);
    });
    _sleepTickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = fireAt.difference(DateTime.now());
      if (remaining.isNegative) return;
      state = state.copyWith(sleepRemaining: remaining);
    });
    state = state.copyWith(
      sleepRemaining: duration,
      sleepAtEndOfTrack: false,
    );
  }

  void setSleepAtEndOfTrack(bool enabled) {
    _cancelSleepTimers();
    state = state.copyWith(
      sleepRemaining: null,
      sleepAtEndOfTrack: enabled,
    );
  }

  void _cancelSleepTimers() {
    _sleepFireTimer?.cancel();
    _sleepTickTimer?.cancel();
    _sleepFireTimer = null;
    _sleepTickTimer = null;
  }

  /// Stop playback and clear the queue. Mini player auto-hides because
  /// `state.current` becomes null. audio_service tears its foreground
  /// service down when we stop reporting a playing state.
  Future<void> stop() async {
    _cancelSleepTimers();
    await player.stop();
    state = state.copyWith(
      queue: const [],
      index: -1,
      position: Duration.zero,
      duration: Duration.zero,
      sleepRemaining: null,
      sleepAtEndOfTrack: false,
    );
    mediaSessionHandler.clearMediaItem();
    _publishToMediaSession();
  }

  // ---- Internals ----

  Future<void> _openCurrent() async {
    final v = state.current;
    if (v == null) return;
    // A new track invalidates the previous A-B selection.
    if (state.loopA != null || state.loopB != null) {
      state = state.copyWith(loopA: null, loopB: null);
    }
    await player.open(Media(v.videoPath));
    if (v.subtitlePath != null) {
      await player.setSubtitleTrack(SubtitleTrack.uri(v.subtitlePath!));
    } else {
      // No sidecar — make sure no leftover track from a previous video
      // bleeds onto this one.
      await player.setSubtitleTrack(SubtitleTrack.no());
    }
    // libmpv resets sub properties on every file open, so push the current
    // preference snapshot through after every successful open().
    final prefs = ref.read(appPreferencesProvider).valueOrNull;
    if (prefs != null) {
      await _applySubtitleStyle(prefs);
    }
    // Honour the user's last-known visibility choice for this play session.
    await _applySubtitleVisibility(state.subtitlesVisible);
    if (state.playbackRate != 1.0) {
      await player.setRate(state.playbackRate);
    }
    _lastPositionSaveAt = DateTime.now();
    if (v.hasResumePoint) {
      await player.seek(v.lastPosition!);
    }
    // Tell the OS what's playing so the lock screen shows title + art.
    mediaSessionHandler.publishMediaItem(v);
    unawaited(_recordHistoryStart(v));
  }

  Future<void> _recordHistoryStart(VideoMetadata v) async {
    try {
      await ref.read(watchHistoryStoreProvider).recordStart(
            WatchEvent(
              videoId: v.id,
              title: v.title,
              startedAt: DateTime.now(),
              endedAt: null,
              lastPosition: v.lastPosition ?? Duration.zero,
              duration: v.duration,
            ),
          );
      ref.read(watchHistoryProvider.notifier).refresh();
    } catch (_) {
      // History is best-effort — swallow disk errors.
    }
  }

  Future<void> toggleSubtitles() async {
    final next = !state.subtitlesVisible;
    state = state.copyWith(subtitlesVisible: next);
    await _applySubtitleVisibility(next);
  }

  Future<void> _applySubtitleVisibility(bool visible) async {
    final native = _player?.platform;
    if (native is! NativePlayer) return;
    try {
      await native.setProperty('sub-visibility', visible ? 'yes' : 'no');
    } catch (_) {
      // Race with file open — next _openCurrent will re-apply.
    }
  }

  Future<void> _applySubtitleStyle(AppPreferences prefs) async {
    if (_player == null) return;
    // The public Player class doesn't expose libmpv property writes — only
    // the native backend does. Cast through to NativePlayer; on Android +
    // iOS the platform is always NativePlayer (see media_kit's Player ctor).
    final native = _player!.platform;
    if (native is! NativePlayer) return;
    try {
      await native.setProperty(
        'sub-font-size',
        prefs.subtitleFontSize.toString(),
      );
      await native.setProperty('sub-color', prefs.subtitleColorHex);
      await native.setProperty('sub-back-color', prefs.subtitleBackgroundHex);
      await native.setProperty(
        'sub-pos',
        prefs.subtitlePosition.toString(),
      );
    } catch (_) {
      // setProperty can race with file open before mpv is ready; ignore.
    }
  }

  void _publishToMediaSession() {
    mediaSessionHandler.publishState(
      playing: state.isPlaying,
      position: state.position,
      duration: state.duration,
      speed: state.playbackRate,
    );
  }

  Future<void> _persistPosition({bool force = false}) async {
    final v = state.current;
    if (v == null) return;
    final pos = state.position;
    if (pos < const Duration(seconds: 3)) return;

    final now = DateTime.now();
    if (!force &&
        _lastPositionSaveAt != null &&
        now.difference(_lastPositionSaveAt!) < _positionSaveInterval) {
      return;
    }
    _lastPositionSaveAt = now;

    if (v.duration > Duration.zero) {
      final fraction = pos.inMilliseconds / v.duration.inMilliseconds;
      if (fraction >= VideoMetadata.finishedThreshold) return;
    }

    final updated = v.copyWith(lastPosition: pos, lastPositionAt: now);
    try {
      await ref.read(videoMetadataStoreProvider).save(updated);
    } catch (_) {
      return;
    }
    _replaceCurrentInQueue(updated);
    unawaited(
      ref
          .read(watchHistoryStoreProvider)
          .updateLatest(v.id, lastPosition: pos)
          .catchError((_) {}),
    );
  }

  void _onTrackCompleted() {
    final v = state.current;
    if (v != null) {
      unawaited(
        ref
            .read(watchHistoryStoreProvider)
            .updateLatest(
              v.id,
              lastPosition: v.duration,
              endedAt: DateTime.now(),
            )
            .catchError((_) {}),
      );
      final cleared = v.copyWith(lastPosition: null, lastPositionAt: null);
      unawaited(
        ref.read(videoMetadataStoreProvider).save(cleared).catchError((_) {}),
      );
      _replaceCurrentInQueue(cleared);
    }
    _autoAdvance();
  }

  void _replaceCurrentInQueue(VideoMetadata updated) {
    if (!state.hasCurrent) return;
    final newQueue = List<VideoMetadata>.from(state.queue);
    newQueue[state.index] = updated;
    state = state.copyWith(queue: newQueue);
    ref.invalidate(libraryListProvider);
  }

  void _autoAdvance() {
    if (state.sleepAtEndOfTrack) {
      state = state.copyWith(sleepAtEndOfTrack: false);
      return;
    }
    final n = _pickNext();
    if (n == null) return;
    state = state.copyWith(index: n);
    unawaited(_openCurrent().then((_) => player.play()));
  }

  int? _pickNext() {
    if (!state.hasCurrent || state.queue.isEmpty) return null;
    if (state.loop == LoopMode.one) return state.index;
    if (state.shuffle) {
      if (state.queue.length == 1) {
        return state.loop == LoopMode.all ? 0 : null;
      }
      int n;
      do {
        n = _random.nextInt(state.queue.length);
      } while (n == state.index);
      return n;
    }
    final next = state.index + 1;
    if (next >= state.queue.length) {
      return state.loop == LoopMode.all ? 0 : null;
    }
    return next;
  }
}

/// keepAlive: the player must NOT be torn down when the player screen pops.
final playbackControllerProvider =
    NotifierProvider<PlaybackController, PlaybackState>(
  PlaybackController.new,
);
