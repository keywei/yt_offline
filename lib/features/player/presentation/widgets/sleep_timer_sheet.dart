import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/playback_providers.dart';

/// Bottom sheet that lets the user pick a sleep-timer preset.
class SleepTimerSheet extends ConsumerWidget {
  const SleepTimerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const SleepTimerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackControllerProvider);
    final controller = ref.read(playbackControllerProvider.notifier);

    Widget item({
      required IconData icon,
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: selected ? const Icon(Icons.check, color: Colors.amber) : null,
        onTap: () {
          onTap();
          Navigator.of(context).pop();
        },
      );
    }

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Sleep timer',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          item(
            icon: Icons.timer_off_outlined,
            label: 'Off',
            selected: !state.hasSleepTimer,
            onTap: () => controller.setSleepTimer(null),
          ),
          item(
            icon: Icons.bedtime_outlined,
            label: '5 minutes',
            selected: state.sleepRemaining != null &&
                state.sleepRemaining! <= const Duration(minutes: 5),
            onTap: () =>
                controller.setSleepTimer(const Duration(minutes: 5)),
          ),
          item(
            icon: Icons.bedtime_outlined,
            label: '15 minutes',
            selected: false,
            onTap: () =>
                controller.setSleepTimer(const Duration(minutes: 15)),
          ),
          item(
            icon: Icons.bedtime_outlined,
            label: '30 minutes',
            selected: false,
            onTap: () =>
                controller.setSleepTimer(const Duration(minutes: 30)),
          ),
          item(
            icon: Icons.bedtime_outlined,
            label: '1 hour',
            selected: false,
            onTap: () =>
                controller.setSleepTimer(const Duration(hours: 1)),
          ),
          const Divider(height: 1),
          item(
            icon: Icons.last_page,
            label: 'End of current track',
            selected: state.sleepAtEndOfTrack,
            onTap: () => controller.setSleepAtEndOfTrack(true),
          ),
        ],
      ),
    );
  }
}
