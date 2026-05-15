import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'features/player/data/media_session_handler.dart';

/// App-wide media session. Initialised here so the OS picks it up before
/// any widget asks for `playbackControllerProvider`. PlaybackController
/// wires its callbacks into this handler in its `build`.
late final MediaSessionHandler mediaSessionHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  mediaSessionHandler = await AudioService.init(
    builder: MediaSessionHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.ytoffline.audio',
      androidNotificationChannelName: 'YT Offline playback',
      androidNotificationOngoing: true,
      androidNotificationIcon: 'drawable/ic_notification',
      androidStopForegroundOnPause: true,
    ),
  );
  runApp(const ProviderScope(child: YtOfflineApp()));
}
