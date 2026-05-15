import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/playback_providers.dart';

class PlaybackSpeedSheet extends ConsumerWidget {
  const PlaybackSpeedSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const PlaybackSpeedSheet(),
    );
  }

  static const _presets = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(
      playbackControllerProvider.select((s) => s.playbackRate),
    );
    final controller = ref.read(playbackControllerProvider.notifier);

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Playback speed',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final rate in _presets)
            ListTile(
              leading: Icon(
                rate == 1.0 ? Icons.speed_outlined : Icons.speed,
              ),
              title: Text(_format(rate)),
              trailing: (rate - current).abs() < 0.001
                  ? const Icon(Icons.check, color: Colors.amber)
                  : null,
              onTap: () {
                controller.setRate(rate);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }

  static String _format(double r) {
    if (r == r.roundToDouble()) return '${r.toInt()}×';
    return '${r.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')}×';
  }
}
