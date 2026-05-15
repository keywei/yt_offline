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

@immutable
class PlaybackState {
  final List<VideoMetadata> queue;
  final int index;
  final LoopMode loop;
  final bool shuffle;
  final bool isPlaying;
  final Duration position;
  final Duration duration;

  const PlaybackState({
    this.queue = const [],
    this.index = -1,
    this.loop = LoopMode.off,
    this.shuffle = false,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  bool get hasCurrent => index >= 0 && index < queue.length;
  VideoMetadata? get current => hasCurrent ? queue[index] : null;

  PlaybackState copyWith({
    List<VideoMetadata>? queue,
    int? index,
    LoopMode? loop,
    bool? shuffle,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
  }) =>
      PlaybackState(
        queue: queue ?? this.queue,
        index: index ?? this.index,
        loop: loop ?? this.loop,
        shuffle: shuffle ?? this.shuffle,
        isPlaying: isPlaying ?? this.isPlaying,
        position: position ?? this.position,
        duration: duration ?? this.duration,
      );
}
