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
  });

  bool get hasCurrent => index >= 0 && index < queue.length;
  VideoMetadata? get current => hasCurrent ? queue[index] : null;
  bool get hasSleepTimer => sleepRemaining != null || sleepAtEndOfTrack;

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
      );
}
