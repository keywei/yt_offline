import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/storage/video_metadata.dart';
import '../state/playback_state.dart';

/// Long-lived [Player] + [VideoController]. Lives in the root ProviderScope
/// so audio survives screen navigation. A foreground service (managed via
/// `flutter_background`) is started on first play so Android keeps the
/// process alive when the app is backgrounded.
class PlaybackController extends Notifier<PlaybackState> {
  Player? _player;
  VideoController? _videoController;
  final _subs = <StreamSubscription<dynamic>>[];
  final _random = Random();
  bool _bgInitialized = false;
  bool _bgEnabled = false;

  Timer? _sleepFireTimer;
  Timer? _sleepTickTimer;

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
      }),
      p.stream.position.listen((d) => state = state.copyWith(position: d)),
      p.stream.duration.listen((d) => state = state.copyWith(duration: d)),
      p.stream.completed.listen((completed) {
        if (completed) _autoAdvance();
      }),
    ]);
    return p;
  }

  @override
  PlaybackState build() {
    ref.onDispose(() {
      for (final s in _subs) {
        s.cancel();
      }
      _cancelSleepTimers();
      _player?.dispose();
      WakelockPlus.disable();
      if (_bgEnabled) {
        unawaited(FlutterBackground.disableBackgroundExecution());
      }
    });
    return const PlaybackState();
  }

  // ---- Public API ----

  Future<void> playQueue(List<VideoMetadata> queue, int startIndex) async {
    await _ensureBackground();
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

  Future<void> seek(Duration to) => player.seek(to);

  /// Update playback rate (0.5x .. 2.0x). Persists across track changes via
  /// `_openCurrent` re-applying it after each `player.open`.
  Future<void> setRate(double rate) async {
    final clamped = rate.clamp(0.25, 4.0);
    await player.setRate(clamped);
    state = state.copyWith(playbackRate: clamped);
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

  // ---- Sleep timer ----

  /// Start a sleep timer that pauses playback after [duration]. Pass null
  /// to cancel. Mutually exclusive with [setSleepAtEndOfTrack].
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

  /// Toggle "pause at end of current track" mode. Cancels any countdown.
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

  /// Stop playback, clear the queue, release the background service.
  /// Mini player auto-hides because `state.current` becomes null.
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
    if (_bgEnabled) {
      try {
        await FlutterBackground.disableBackgroundExecution();
      } catch (_) {}
      _bgEnabled = false;
    }
  }

  // ---- Internals ----

  Future<void> _ensureBackground() async {
    if (_bgEnabled) return;
    try {
      if (!_bgInitialized) {
        debugPrint('[bg] hasPermissions check…');
        final hasPerms = await FlutterBackground.hasPermissions;
        debugPrint('[bg] hasPermissions=$hasPerms');
        debugPrint('[bg] calling initialize()…');
        final ok = await FlutterBackground.initialize(
          androidConfig: const FlutterBackgroundAndroidConfig(
            notificationTitle: 'YT Offline',
            notificationText: 'Playing in background',
            notificationImportance: AndroidNotificationImportance.normal,
            // Notification small icon must be a white-on-transparent drawable;
            // colored mipmaps get silently rejected by Android 5+.
            notificationIcon:
                AndroidResource(name: 'ic_notification', defType: 'drawable'),
            enableWifiLock: true,
          ),
        );
        debugPrint('[bg] initialize() returned: $ok');
        _bgInitialized = ok;
        if (!ok) return;
      }
      debugPrint('[bg] calling enableBackgroundExecution()…');
      _bgEnabled = await FlutterBackground.enableBackgroundExecution();
      debugPrint('[bg] enabled=$_bgEnabled (running=${FlutterBackground.isBackgroundExecutionEnabled})');
    } catch (e, st) {
      debugPrint('[bg] FAILED: $e\n$st');
    }
  }

  Future<void> _openCurrent() async {
    final v = state.current;
    if (v == null) return;
    await player.open(Media(v.videoPath));
    if (v.subtitlePath != null) {
      await player.setSubtitleTrack(SubtitleTrack.uri(v.subtitlePath!));
    }
    // mpv resets playback rate to 1.0 on every open(); re-apply the user's
    // chosen rate so switching tracks doesn't snap back to normal speed.
    if (state.playbackRate != 1.0) {
      await player.setRate(state.playbackRate);
    }
  }

  void _autoAdvance() {
    // Honour the "stop at end of current track" sleep mode: don't advance,
    // just clear the flag.
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
