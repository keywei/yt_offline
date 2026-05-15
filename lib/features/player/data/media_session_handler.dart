import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

import '../../../core/storage/video_metadata.dart';

/// Bridges OS-level media controls (Android MediaSession, iOS
/// MPNowPlayingInfoCenter / MPRemoteCommandCenter, headset buttons) to
/// [PlaybackController].
///
/// Created once in `main()` via `AudioService.init`. Lives for the app's
/// life. PlaybackController wires its callbacks during `build()`.
class MediaSessionHandler extends BaseAudioHandler {
  VoidCallback? onPlay;
  VoidCallback? onPause;
  VoidCallback? onNext;
  VoidCallback? onPrevious;
  ValueChanged<Duration>? onSeek;
  VoidCallback? onStop;

  /// Push current playback state to audio_service so the OS UI reflects it.
  void publishState({
    required bool playing,
    required Duration position,
    required Duration duration,
    required double speed,
  }) {
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
        },
        // Show prev/play-pause/next in the compact notification on Android.
        androidCompactActionIndices: const [0, 1, 2],
        playing: playing,
        processingState: AudioProcessingState.ready,
        updatePosition: position,
        speed: speed,
      ),
    );
  }

  /// Push current track info so OS UI shows title / artist / artwork.
  void publishMediaItem(VideoMetadata video) {
    mediaItem.add(
      MediaItem(
        id: video.id,
        title: video.title,
        artist: video.author,
        album: video.category,
        duration: video.duration,
        artUri: Uri.parse(video.thumbnailUrl),
      ),
    );
  }

  void clearMediaItem() {
    mediaItem.add(null);
  }

  @override
  Future<void> play() async => onPlay?.call();

  @override
  Future<void> pause() async => onPause?.call();

  @override
  Future<void> skipToNext() async => onNext?.call();

  @override
  Future<void> skipToPrevious() async => onPrevious?.call();

  @override
  Future<void> seek(Duration position) async => onSeek?.call(position);

  @override
  Future<void> stop() async {
    onStop?.call();
    await super.stop();
  }
}
