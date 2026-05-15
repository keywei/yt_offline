import 'package:flutter/foundation.dart';

import '../../../../core/storage/video_metadata.dart';

enum LoopMode {
  off,
  one,
  all;

  LoopMode get next => switch (this) {
        off => all,
        all => one,
        one => off,
      };
}

/// Sentinel used by [PlaybackState.copyWith] to tell apart "leave the
/// previous value alone" from "explicitly set to null" for nullable fields.
const Object _unchanged = Object();

@immutable
class PlaybackState {
  final List<VideoMetadata> queue;
  final int index;
  final LoopMode loop;
  final bool shuffle;
  final bool isPlaying;
  final Duration position;
  final Duration duration;

  /// Live countdown of the running sleep timer; null means no timer set.
  final Duration? sleepRemaining;

  /// When true, playback pauses at the end of the currently-playing track
  /// instead of auto-advancing to the next one.
  final bool sleepAtEndOfTrack;

  /// Current playback rate. 1.0 = normal speed.
  final double playbackRate;

  /// A-B segment loop endpoints. When both are set and `loopA < loopB`,
  /// playback wraps from B back to A. Cleared automatically on track
  /// change. Session-scoped — not persisted.
  final Duration? loopA;
  final Duration? loopB;

  const PlaybackState({
    this.queue = const [],
    this.index = -1,
    this.loop = LoopMode.off,
    this.shuffle = false,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.sleepRemaining,
    this.sleepAtEndOfTrack = false,
    this.playbackRate = 1.0,
    this.loopA,
    this.loopB,
  });

  bool get hasCurrent => index >= 0 && index < queue.length;
  VideoMetadata? get current => hasCurrent ? queue[index] : null;
  bool get hasSleepTimer => sleepRemaining != null || sleepAtEndOfTrack;

  /// Both endpoints set and ordered — only then does the loop fire.
  bool get hasActiveABLoop =>
      loopA != null && loopB != null && loopA! < loopB!;

  PlaybackState copyWith({
    List<VideoMetadata>? queue,
    int? index,
    LoopMode? loop,
    bool? shuffle,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    Object? sleepRemaining = _unchanged,
    bool? sleepAtEndOfTrack,
    double? playbackRate,
    Object? loopA = _unchanged,
    Object? loopB = _unchanged,
  }) =>
      PlaybackState(
        queue: queue ?? this.queue,
        index: index ?? this.index,
        loop: loop ?? this.loop,
        shuffle: shuffle ?? this.shuffle,
        isPlaying: isPlaying ?? this.isPlaying,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        sleepRemaining: identical(sleepRemaining, _unchanged)
            ? this.sleepRemaining
            : sleepRemaining as Duration?,
        sleepAtEndOfTrack: sleepAtEndOfTrack ?? this.sleepAtEndOfTrack,
        playbackRate: playbackRate ?? this.playbackRate,
        loopA: identical(loopA, _unchanged) ? this.loopA : loopA as Duration?,
        loopB: identical(loopB, _unchanged) ? this.loopB : loopB as Duration?,
      );
}
