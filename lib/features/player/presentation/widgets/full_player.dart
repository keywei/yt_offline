import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../core/i18n/strings.dart';
import '../providers/playback_providers.dart';
import '../state/playback_state.dart';
import 'playback_speed_sheet.dart';
import 'sleep_timer_sheet.dart';

/// Same channel name used by `AppDelegate.swift` on the iOS side.
const _orientationChannel = MethodChannel('yt_offline/orientation');

/// Briefly lock the device to the given orientations to trigger rotation,
/// then release so the sensor can take over again. Without the release the
/// device would stay pinned and the user couldn't rotate back manually.
///
/// On iOS, [SystemChrome.setPreferredOrientations] only declares *what is
/// allowed* — it does not physically rotate. We additionally invoke a
/// native MethodChannel that calls `requestGeometryUpdate` on iOS 16+ (or
/// the legacy "orientation" KVC trick on older versions) to force the
/// rotation right away.
Future<void> _flipOrientation(List<DeviceOrientation> target) async {
  await SystemChrome.setPreferredOrientations(target);
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    final mode = target.first == DeviceOrientation.portraitUp
        ? 'portrait'
        : 'landscape';
    try {
      await _orientationChannel.invokeMethod<void>('force', mode);
    } catch (_) {
      // The channel might not be wired in unit tests; ignore.
    }
  }
  Future.delayed(const Duration(seconds: 1), () {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  });
}

const _landscapes = [
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

const _portrait = [DeviceOrientation.portraitUp];

/// The "Now Playing" surface. Renders the Video widget plus transport
/// controls. Designed to live permanently in the widget tree (inside
/// [NowPlayingShell]) so the Video widget is never re-mounted — that
/// re-mount is what stalls libmpv on iOS.
///
/// When [landscape] is true, the layout becomes a YouTube-style fullscreen
/// player: video fills the screen and the controls auto-hide.
class FullPlayer extends ConsumerWidget {
  final VoidCallback onCollapse;
  final bool landscape;

  /// Shared between portrait and landscape layouts so the [Video] widget's
  /// Element/State survives rotation. Without it the layout swap remounts
  /// Video, which stalls libmpv on iOS the same way the mini→full route push
  /// used to.
  static final GlobalKey videoKey = GlobalKey();

  const FullPlayer({
    required this.onCollapse,
    this.landscape = false,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackControllerProvider);
    final controller = ref.read(playbackControllerProvider.notifier);

    if (landscape) {
      return _LandscapeLayout(
        state: state,
        controller: controller,
        onCollapse: onCollapse,
      );
    }
    return _PortraitLayout(
      state: state,
      controller: controller,
      onCollapse: onCollapse,
    );
  }
}

class _PortraitLayout extends StatelessWidget {
  final PlaybackState state;
  final PlaybackController controller;
  final VoidCallback onCollapse;

  const _PortraitLayout({
    required this.state,
    required this.controller,
    required this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final current = state.current;
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            _TopBar(title: current?.title, onCollapse: onCollapse),
            if (current != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${S.of(context).displayCategory(current.category)} • ${state.index + 1} / ${state.queue.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  Video(
                    key: FullPlayer.videoKey,
                    controller: controller.videoController,
                    pauseUponEnteringBackgroundMode: false,
                    // Hide media_kit's built-in MaterialVideoControls; we
                    // own the entire UI ourselves.
                    controls: (_) => const SizedBox.shrink(),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: IconButton(
                      tooltip: S.of(context).fullscreen,
                      icon: const Icon(
                        Icons.fullscreen,
                        color: Colors.white,
                      ),
                      onPressed: () => _flipOrientation(_landscapes),
                    ),
                  ),
                ],
              ),
            ),
            _Scrubber(state: state, controller: controller),
            _Controls(state: state, controller: controller),
            Expanded(child: _Queue(state: state, controller: controller)),
          ],
        ),
      ),
    );
  }
}

/// YouTube-style landscape layout: black canvas, video fills the screen,
/// controls auto-hide after 3s of inactivity.
class _LandscapeLayout extends StatefulWidget {
  final PlaybackState state;
  final PlaybackController controller;
  final VoidCallback onCollapse;

  const _LandscapeLayout({
    required this.state,
    required this.controller,
    required this.onCollapse,
  });

  @override
  State<_LandscapeLayout> createState() => _LandscapeLayoutState();
}

class _LandscapeLayoutState extends State<_LandscapeLayout> {
  bool _overlayVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!widget.state.isPlaying) return; // keep visible while paused
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _overlayVisible = false);
    });
  }

  void _toggleOverlay() {
    setState(() => _overlayVisible = !_overlayVisible);
    if (_overlayVisible) _scheduleHide();
  }

  void _bumpHide() {
    if (!_overlayVisible) {
      setState(() => _overlayVisible = true);
    }
    _scheduleHide();
  }

  @override
  void didUpdateWidget(covariant _LandscapeLayout old) {
    super.didUpdateWidget(old);
    if (widget.state.isPlaying != old.state.isPlaying) {
      _scheduleHide();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final controller = widget.controller;
    final current = state.current;
    return Material(
      color: Colors.black,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleOverlay,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video stretched to fill the screen.
            Video(
              key: FullPlayer.videoKey,
              controller: controller.videoController,
              pauseUponEnteringBackgroundMode: false,
              controls: (_) => const SizedBox.shrink(),
              fit: BoxFit.contain,
            ),
            AnimatedOpacity(
              opacity: _overlayVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_overlayVisible,
                child: _LandscapeOverlay(
                  state: state,
                  controller: controller,
                  title: current?.title ?? '',
                  onCollapse: widget.onCollapse,
                  onAnyInteraction: _bumpHide,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandscapeOverlay extends StatelessWidget {
  final PlaybackState state;
  final PlaybackController controller;
  final String title;
  final VoidCallback onCollapse;
  final VoidCallback onAnyInteraction;

  const _LandscapeOverlay({
    required this.state,
    required this.controller,
    required this.title,
    required this.onCollapse,
    required this.onAnyInteraction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.5),
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.5),
          ],
          stops: const [0.0, 0.2, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _TopBar(
              title: title,
              onCollapse: () {
                onAnyInteraction();
                onCollapse();
              },
            ),
            const Spacer(),
            // Centre transport row, large hit targets.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _BigIcon(
                  icon: Icons.skip_previous,
                  size: 44,
                  onPressed: () {
                    onAnyInteraction();
                    controller.previous();
                  },
                ),
                _BigIcon(
                  icon: state.isPlaying
                      ? Icons.pause_circle
                      : Icons.play_circle,
                  size: 72,
                  onPressed: () {
                    onAnyInteraction();
                    controller.togglePlayPause();
                  },
                ),
                _BigIcon(
                  icon: Icons.skip_next,
                  size: 44,
                  onPressed: () {
                    onAnyInteraction();
                    controller.next();
                  },
                ),
              ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _Scrubber(state: state, controller: controller),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.speed,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      onAnyInteraction();
                      PlaybackSpeedSheet.show(context);
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      state.hasSleepTimer
                          ? Icons.bedtime
                          : Icons.bedtime_outlined,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      onAnyInteraction();
                      SleepTimerSheet.show(context);
                    },
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: S.of(context).exitFullscreen,
                    icon: const Icon(
                      Icons.fullscreen_exit,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      onAnyInteraction();
                      _flipOrientation(_portrait);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onPressed;
  const _BigIcon({
    required this.icon,
    required this.size,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: size,
      icon: Icon(icon, color: Colors.white),
      onPressed: onPressed,
    );
  }
}

class _TopBar extends StatelessWidget {
  final String? title;
  final VoidCallback onCollapse;
  const _TopBar({required this.title, required this.onCollapse});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kToolbarHeight,
      child: Row(
        children: [
          IconButton(
            tooltip: S.of(context).collapse,
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
            onPressed: onCollapse,
          ),
          Expanded(
            child: Text(
              title ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _Scrubber extends StatelessWidget {
  final PlaybackState state;
  final PlaybackController controller;
  const _Scrubber({required this.state, required this.controller});

  @override
  Widget build(BuildContext context) {
    final pos = state.position.inMilliseconds.toDouble();
    final dur = state.duration.inMilliseconds.toDouble();
    final maxV = dur > 0 ? dur : 1.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text(_fmt(state.position), style: _timeStyle),
          Expanded(
            child: Slider(
              value: pos.clamp(0, maxV),
              max: maxV,
              onChanged: (v) =>
                  controller.seek(Duration(milliseconds: v.toInt())),
            ),
          ),
          Text(_fmt(state.duration), style: _timeStyle),
        ],
      ),
    );
  }

  static const _timeStyle = TextStyle(color: Colors.white70, fontSize: 11);

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _Controls extends StatelessWidget {
  final PlaybackState state;
  final PlaybackController controller;
  const _Controls({required this.state, required this.controller});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: s.shuffle,
                icon: Icon(
                  Icons.shuffle,
                  color: state.shuffle ? Colors.amber : Colors.white70,
                ),
                onPressed: controller.toggleShuffle,
              ),
              IconButton(
                iconSize: 36,
                tooltip: s.previous,
                icon: const Icon(Icons.skip_previous, color: Colors.white),
                onPressed: controller.previous,
              ),
              IconButton(
                iconSize: 56,
                tooltip: state.isPlaying ? s.pause : s.play,
                icon: Icon(
                  state.isPlaying ? Icons.pause_circle : Icons.play_circle,
                  color: Colors.white,
                ),
                onPressed: controller.togglePlayPause,
              ),
              IconButton(
                iconSize: 36,
                tooltip: s.next,
                icon: const Icon(Icons.skip_next, color: Colors.white),
                onPressed: controller.next,
              ),
              IconButton(
                tooltip: s.loopMode(state.loop.name),
                icon: Icon(
                  switch (state.loop) {
                    LoopMode.off => Icons.repeat,
                    LoopMode.all => Icons.repeat_on,
                    LoopMode.one => Icons.repeat_one_on,
                  },
                  color: state.loop == LoopMode.off
                      ? Colors.white70
                      : Colors.amber,
                ),
                onPressed: controller.cycleLoopMode,
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _SpeedButton(state: state),
              _SleepTimerButton(state: state),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  final PlaybackState state;
  const _SpeedButton({required this.state});

  @override
  Widget build(BuildContext context) {
    final active = state.playbackRate != 1.0;
    final label = state.playbackRate == state.playbackRate.roundToDouble()
        ? '${state.playbackRate.toInt()}×'
        : '${state.playbackRate}×';
    return TextButton.icon(
      onPressed: () => PlaybackSpeedSheet.show(context),
      icon: Icon(
        Icons.speed,
        size: 18,
        color: active ? Colors.amber : Colors.white70,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: active ? Colors.amber : Colors.white70,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SleepTimerButton extends StatelessWidget {
  final PlaybackState state;
  const _SleepTimerButton({required this.state});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final active = state.hasSleepTimer;
    final label = state.sleepAtEndOfTrack
        ? s.endOfTrack
        : state.sleepRemaining == null
            ? s.sleep
            : _formatRemaining(state.sleepRemaining!);
    return TextButton.icon(
      onPressed: () => SleepTimerSheet.show(context),
      icon: Icon(
        active ? Icons.bedtime : Icons.bedtime_outlined,
        size: 18,
        color: active ? Colors.amber : Colors.white70,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: active ? Colors.amber : Colors.white70,
          fontSize: 12,
        ),
      ),
    );
  }

  String _formatRemaining(Duration d) {
    if (d.inHours > 0) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      return '${d.inHours}:$m';
    }
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _Queue extends StatelessWidget {
  final PlaybackState state;
  final PlaybackController controller;
  const _Queue({required this.state, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: state.queue.length,
      itemBuilder: (context, i) {
        final v = state.queue[i];
        final active = i == state.index;
        return ListTile(
          dense: true,
          leading: Icon(
            active ? Icons.play_arrow : Icons.music_note_outlined,
            color: active ? Colors.amber : Colors.white54,
            size: 20,
          ),
          title: Text(
            v.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? Colors.amber : Colors.white,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Text(
            v.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          onTap: active ? null : () => controller.jumpTo(i),
        );
      },
    );
  }
}
