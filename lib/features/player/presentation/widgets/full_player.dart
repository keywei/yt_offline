import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../../../core/i18n/strings.dart';
import '../../../../core/pip/pip_controller.dart';
import '../providers/playback_providers.dart';
import '../state/playback_state.dart';
import 'playback_speed_sheet.dart';
import 'sleep_timer_sheet.dart';
import 'volume_sheet.dart';

/// Same channel name used by `AppDelegate.swift` on the iOS side.
const _orientationChannel = MethodChannel('yt_offline/orientation');

/// Lock the device to the given orientations and physically rotate.
///
/// On iOS, [SystemChrome.setPreferredOrientations] only declares *what is
/// allowed* — it does not physically rotate. We additionally invoke a
/// native MethodChannel that calls `requestGeometryUpdate` on iOS 16+ (or
/// the legacy "orientation" KVC trick on older versions) to force the
/// rotation right away.
///
/// The "preferred orientations" pin is only released after returning to
/// portrait. If we released right after forcing landscape, iOS would
/// re-evaluate against the system portrait lock (control-centre rotation
/// lock) and snap us back to portrait mid-playback.
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
  final returningToPortrait =
      target.length == 1 && target.first == DeviceOrientation.portraitUp;
  if (returningToPortrait) {
    Future.delayed(const Duration(seconds: 1), () {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    });
  }
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

/// Which gesture is currently mid-drag — drives the floating indicator on
/// the right-hand `_GestureIndicator`.
enum _ActiveGesture { brightness, volume, seek }

class _LandscapeLayoutState extends State<_LandscapeLayout> {
  bool _overlayVisible = true;
  Timer? _hideTimer;

  // Gesture transient state.
  _ActiveGesture? _activeGesture;
  double _gestureValue = 0; // 0..1 for brightness/volume
  Duration _seekTarget = Duration.zero;
  Duration _seekStart = Duration.zero;
  double _brightnessStart = 0;
  double _volumeStart = 0;
  Timer? _indicatorHideTimer;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _indicatorHideTimer?.cancel();
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

  // ---- Gesture handlers ----

  Future<void> _onVerticalDragStart(DragStartDetails d) async {
    final width = MediaQuery.of(context).size.width;
    final onLeft = d.localPosition.dx < width / 2;
    try {
      if (onLeft) {
        _brightnessStart = await ScreenBrightness().application;
        setState(() {
          _activeGesture = _ActiveGesture.brightness;
          _gestureValue = _brightnessStart;
        });
      } else {
        _volumeStart = await FlutterVolumeController.getVolume() ?? 0.5;
        setState(() {
          _activeGesture = _ActiveGesture.volume;
          _gestureValue = _volumeStart;
        });
      }
    } catch (_) {
      // Platform call failed (eg. permission). Bail out — the swipe simply
      // does nothing.
      setState(() => _activeGesture = null);
    }
  }

  Future<void> _onVerticalDragUpdate(DragUpdateDetails d) async {
    final active = _activeGesture;
    if (active == null) return;
    if (active == _ActiveGesture.seek) return;
    final height = MediaQuery.of(context).size.height;
    // Negative dy = moving up (a value increase). Use total primary delta
    // since the last update to converge on a stable final value rather than
    // accumulate drift.
    final delta = -d.primaryDelta! / height;
    final next = (_gestureValue + delta).clamp(0.0, 1.0);
    setState(() => _gestureValue = next);
    try {
      if (active == _ActiveGesture.brightness) {
        await ScreenBrightness().setApplicationScreenBrightness(next);
      } else {
        await FlutterVolumeController.setVolume(next);
      }
    } catch (_) {
      // Ignore — the next update will retry.
    }
  }

  void _onVerticalDragEnd(DragEndDetails _) {
    _scheduleIndicatorHide();
  }

  void _onHorizontalDragStart(DragStartDetails _) {
    final pos = widget.state.position;
    setState(() {
      _activeGesture = _ActiveGesture.seek;
      _seekStart = pos;
      _seekTarget = pos;
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    if (_activeGesture != _ActiveGesture.seek) return;
    final width = MediaQuery.of(context).size.width;
    // A full-screen horizontal sweep maps to a 90-second nudge — long
    // enough to be useful, short enough to be precise.
    const fullSweepSeconds = 90;
    final accumDx = d.primaryDelta!;
    final deltaSec = (accumDx / width) * fullSweepSeconds;
    final next = _seekTarget +
        Duration(milliseconds: (deltaSec * 1000).round());
    final total = widget.state.duration;
    final clamped = next.isNegative
        ? Duration.zero
        : (total > Duration.zero && next > total ? total : next);
    setState(() => _seekTarget = clamped);
  }

  Future<void> _onHorizontalDragEnd(DragEndDetails _) async {
    if (_activeGesture != _ActiveGesture.seek) return;
    if (_seekTarget != _seekStart) {
      await widget.controller.seek(_seekTarget);
    }
    _scheduleIndicatorHide();
  }

  void _onDoubleTapDown(TapDownDetails d) {
    final width = MediaQuery.of(context).size.width;
    final x = d.localPosition.dx;
    if (x < width / 3) {
      _doubleTapSeek(-10);
    } else if (x > width * 2 / 3) {
      _doubleTapSeek(10);
    }
  }

  void _doubleTapSeek(int seconds) {
    final current = widget.state.position;
    final total = widget.state.duration;
    var next = current + Duration(seconds: seconds);
    if (next.isNegative) next = Duration.zero;
    if (total > Duration.zero && next > total) next = total;
    widget.controller.seek(next);
    setState(() {
      _activeGesture = _ActiveGesture.seek;
      _seekStart = current;
      _seekTarget = next;
    });
    _scheduleIndicatorHide();
  }

  void _scheduleIndicatorHide() {
    _indicatorHideTimer?.cancel();
    _indicatorHideTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() => _activeGesture = null);
    });
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
        onDoubleTapDown: _onDoubleTapDown,
        onDoubleTap: () {},
        onVerticalDragStart: _onVerticalDragStart,
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        onHorizontalDragStart: _onHorizontalDragStart,
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        onHorizontalDragEnd: _onHorizontalDragEnd,
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
            // Floating brightness / volume / seek indicator. Only rendered
            // while a gesture is active.
            if (_activeGesture != null)
              IgnorePointer(
                child: Center(
                  child: _GestureIndicator(
                    gesture: _activeGesture!,
                    value: _gestureValue,
                    seekTarget: _seekTarget,
                    seekStart: _seekStart,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GestureIndicator extends StatelessWidget {
  final _ActiveGesture gesture;
  final double value;
  final Duration seekTarget;
  final Duration seekStart;
  const _GestureIndicator({
    required this.gesture,
    required this.value,
    required this.seekTarget,
    required this.seekStart,
  });

  @override
  Widget build(BuildContext context) {
    final body = switch (gesture) {
      _ActiveGesture.brightness => _bar(
          Icons.brightness_6,
          (value * 100).round(),
        ),
      _ActiveGesture.volume => _bar(
          value < 0.01 ? Icons.volume_off : Icons.volume_up,
          (value * 100).round(),
        ),
      _ActiveGesture.seek => _seekBlock(context),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
      ),
      child: body,
    );
  }

  Widget _bar(IconData icon, int pct) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          SizedBox(
            width: 140,
            child: LinearProgressIndicator(
              value: value.clamp(0, 1),
              backgroundColor: Colors.white24,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 32,
            child: Text(
              '$pct%',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      );

  Widget _seekBlock(BuildContext context) {
    final diff = seekTarget - seekStart;
    final sign = diff.isNegative ? '−' : '+';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          diff.isNegative ? Icons.fast_rewind : Icons.fast_forward,
          color: Colors.white,
          size: 22,
        ),
        const SizedBox(width: 12),
        Text(
          _fmt(seekTarget),
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        Text(
          '  ($sign${_fmt(Duration(milliseconds: diff.inMilliseconds.abs()))})',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
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
                    tooltip: S.of(context).volumeTitle,
                    icon: const Icon(
                      Icons.volume_up,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      onAnyInteraction();
                      VolumeSheet.show(context);
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
                  Builder(
                    builder: (_) {
                      final hasSubs = state.current?.subtitlePath != null;
                      final on = state.subtitlesVisible;
                      return IconButton(
                        tooltip: hasSubs
                            ? (on
                                ? S.of(context).subtitlesOn
                                : S.of(context).subtitlesOff)
                            : S.of(context).subtitlesNone,
                        icon: Icon(
                          on ? Icons.subtitles : Icons.subtitles_off,
                          color: !hasSubs
                              ? Colors.white24
                              : (on ? Colors.amber : Colors.white),
                        ),
                        onPressed: !hasSubs
                            ? null
                            : () {
                                onAnyInteraction();
                                controller.toggleSubtitles();
                              },
                      );
                    },
                  ),
                  _ABPill(
                    label: S.of(context).abPointA,
                    time: state.loopA,
                    active: state.loopA != null,
                    onPressed: () {
                      onAnyInteraction();
                      controller.setLoopA();
                    },
                  ),
                  _ABPill(
                    label: S.of(context).abPointB,
                    time: state.loopB,
                    active: state.loopB != null,
                    onPressed: () {
                      onAnyInteraction();
                      controller.setLoopB();
                    },
                  ),
                  if (state.loopA != null || state.loopB != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: S.of(context).abClear,
                      icon: const Icon(Icons.close,
                          color: Colors.white70, size: 18),
                      onPressed: () {
                        onAnyInteraction();
                        controller.clearLoopAB();
                      },
                    ),
                  const Spacer(),
                  Consumer(
                    builder: (context, ref, _) {
                      final supported =
                          ref.watch(pipSupportedProvider).valueOrNull ?? false;
                      if (!supported) return const SizedBox.shrink();
                      return IconButton(
                        tooltip: S.of(context).pipEnter,
                        icon: const Icon(
                          Icons.picture_in_picture_alt,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          onAnyInteraction();
                          ref.read(pipControllerProvider).enter();
                        },
                      );
                    },
                  ),
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
            child: Stack(
              alignment: Alignment.center,
              children: [
                // A-B loop range strip painted underneath the slider thumb.
                if (dur > 0 && (state.loopA != null || state.loopB != null))
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final a = (state.loopA?.inMilliseconds ?? 0) / dur;
                        final b = (state.loopB?.inMilliseconds ?? dur) / dur;
                        return CustomPaint(
                          painter: _LoopRangePainter(
                            startFraction: a.clamp(0, 1).toDouble(),
                            endFraction: b.clamp(0, 1).toDouble(),
                            hasBoth: state.hasActiveABLoop,
                          ),
                        );
                      },
                    ),
                  ),
                Slider(
                  value: pos.clamp(0, maxV),
                  max: maxV,
                  onChanged: (v) =>
                      controller.seek(Duration(milliseconds: v.toInt())),
                ),
              ],
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

class _LoopRangePainter extends CustomPainter {
  final double startFraction;
  final double endFraction;
  final bool hasBoth;
  _LoopRangePainter({
    required this.startFraction,
    required this.endFraction,
    required this.hasBoth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // The Slider's track sits at vertical centre. Sliders also reserve
    // ~24px of padding at each horizontal edge for the thumb — match that
    // so the painted range lines up with the time the user actually
    // selected.
    const horizontalPadding = 24.0;
    final trackY = size.height / 2;
    final usable = size.width - horizontalPadding * 2;
    if (usable <= 0) return;
    final startX = horizontalPadding + usable * startFraction;
    final endX = horizontalPadding + usable * endFraction;
    final rangePaint = Paint()
      ..color = (hasBoth ? Colors.amber : Colors.amber.withValues(alpha: 0.4))
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(startX, trackY), Offset(endX, trackY), rangePaint);
  }

  @override
  bool shouldRepaint(_LoopRangePainter old) =>
      old.startFraction != startFraction ||
      old.endFraction != endFraction ||
      old.hasBoth != hasBoth;
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
              _VolumeButton(),
              _SleepTimerButton(state: state),
              _SubtitleToggle(state: state, controller: controller),
              _ABLoopControls(state: state, controller: controller),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubtitleToggle extends StatelessWidget {
  final PlaybackState state;
  final PlaybackController controller;
  const _SubtitleToggle({required this.state, required this.controller});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final hasSubs = state.current?.subtitlePath != null;
    final on = state.subtitlesVisible;
    final colour = !hasSubs
        ? Colors.white24
        : (on ? Colors.amber : Colors.white70);
    return TextButton.icon(
      onPressed: hasSubs ? controller.toggleSubtitles : null,
      icon: Icon(
        on ? Icons.subtitles : Icons.subtitles_off,
        size: 18,
        color: colour,
      ),
      label: Text(
        hasSubs ? (on ? s.subtitlesOn : s.subtitlesOff) : s.subtitlesNone,
        style: TextStyle(color: colour, fontSize: 12),
      ),
    );
  }
}

class _ABLoopControls extends StatelessWidget {
  final PlaybackState state;
  final PlaybackController controller;
  const _ABLoopControls({required this.state, required this.controller});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final aSet = state.loopA != null;
    final bSet = state.loopB != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ABPill(
          label: s.abPointA,
          time: state.loopA,
          active: aSet,
          onPressed: () => controller.setLoopA(),
        ),
        const SizedBox(width: 4),
        _ABPill(
          label: s.abPointB,
          time: state.loopB,
          active: bSet,
          onPressed: () => controller.setLoopB(),
        ),
        if (aSet || bSet)
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: s.abClear,
            icon: const Icon(Icons.close, color: Colors.white70, size: 18),
            onPressed: controller.clearLoopAB,
          ),
      ],
    );
  }
}

class _ABPill extends StatelessWidget {
  final String label;
  final Duration? time;
  final bool active;
  final VoidCallback onPressed;

  const _ABPill({
    required this.label,
    required this.time,
    required this.active,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.amber : Colors.white70;
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 12)),
          if (time != null) ...[
            const SizedBox(width: 4),
            Text(
              _fmt(time!),
              style: TextStyle(color: color, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
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

class _VolumeButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => VolumeSheet.show(context),
      icon: const Icon(
        Icons.volume_up,
        size: 18,
        color: Colors.white70,
      ),
      label: Text(
        S.of(context).volumeTitle,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
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
