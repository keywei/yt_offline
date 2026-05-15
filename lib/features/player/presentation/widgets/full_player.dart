import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../providers/playback_providers.dart';
import '../state/playback_state.dart';
import 'sleep_timer_sheet.dart';

/// The expanded "Now Playing" surface. Renders the Video widget, scrubber,
/// transport controls and the current queue. Designed to live permanently in
/// the widget tree (inside [NowPlayingShell]) so the Video widget is never
/// re-mounted — that re-mount is what stalls libmpv on iOS.
class FullPlayer extends ConsumerWidget {
  final VoidCallback onCollapse;
  const FullPlayer({required this.onCollapse, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackControllerProvider);
    final controller = ref.read(playbackControllerProvider.notifier);
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
                  '${current.category} • ${state.index + 1} / ${state.queue.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            AspectRatio(
              aspectRatio: 16 / 9,
              // pauseUponEnteringBackgroundMode is false because we want audio
              // to keep playing when the app is sent to the background.
              child: Video(
                controller: controller.videoController,
                pauseUponEnteringBackgroundMode: false,
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
            tooltip: 'Collapse',
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: 'Shuffle',
                icon: Icon(
                  Icons.shuffle,
                  color: state.shuffle ? Colors.amber : Colors.white70,
                ),
                onPressed: controller.toggleShuffle,
              ),
              IconButton(
                iconSize: 36,
                tooltip: 'Previous',
                icon: const Icon(Icons.skip_previous, color: Colors.white),
                onPressed: controller.previous,
              ),
              IconButton(
                iconSize: 56,
                tooltip: state.isPlaying ? 'Pause' : 'Play',
                icon: Icon(
                  state.isPlaying ? Icons.pause_circle : Icons.play_circle,
                  color: Colors.white,
                ),
                onPressed: controller.togglePlayPause,
              ),
              IconButton(
                iconSize: 36,
                tooltip: 'Next',
                icon: const Icon(Icons.skip_next, color: Colors.white),
                onPressed: controller.next,
              ),
              IconButton(
                tooltip: 'Loop: ${state.loop.name}',
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SleepTimerButton(state: state),
            ],
          ),
        ],
      ),
    );
  }
}

class _SleepTimerButton extends StatelessWidget {
  final PlaybackState state;
  const _SleepTimerButton({required this.state});

  @override
  Widget build(BuildContext context) {
    final active = state.hasSleepTimer;
    final label = state.sleepAtEndOfTrack
        ? 'End of track'
        : state.sleepRemaining == null
            ? 'Sleep'
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
