import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../providers/playback_providers.dart';
import '../state/playback_state.dart';

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackControllerProvider);
    final controller = ref.read(playbackControllerProvider.notifier);

    final current = state.current;
    if (current == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Nothing to play.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          current.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '${current.category} • ${state.index + 1} / ${state.queue.length}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            // pauseUponEnteringBackgroundMode defaults to true — Video widget
            // calls player.pause() on AppLifecycleState.paused. We rely on
            // the foreground service instead and want audio to keep going.
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
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
              color: state.loop == LoopMode.off ? Colors.white70 : Colors.amber,
            ),
            onPressed: controller.cycleLoopMode,
          ),
        ],
      ),
    );
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
