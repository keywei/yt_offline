import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/strings.dart';
import '../providers/playback_providers.dart';

/// Bottom sheet that lets the user pick a sleep-timer preset.
class SleepTimerSheet extends ConsumerWidget {
  const SleepTimerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      // Cap sheet at 90% of screen height. Without a hard cap, isScrollControlled
      // lets the sheet pass unbounded vertical constraints to its child — the
      // inner SingleChildScrollView's viewport ends up equal to the full
      // natural content height, so it never scrolls, and the system just
      // clips the sheet at the screen edge (bottom rows un-tappable in
      // landscape). The cap creates a real bounded viewport so the inner
      // scroll can do its job.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
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

    final s = S.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                s.sleepTimer,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            item(
              icon: Icons.timer_off_outlined,
              label: s.sleepOff,
              selected: !state.hasSleepTimer,
              onTap: () => controller.setSleepTimer(null),
            ),
            item(
              icon: Icons.bedtime_outlined,
              label: s.sleepMinutes5,
              selected: state.sleepRemaining != null &&
                  state.sleepRemaining! <= const Duration(minutes: 5),
              onTap: () =>
                  controller.setSleepTimer(const Duration(minutes: 5)),
            ),
            item(
              icon: Icons.bedtime_outlined,
              label: s.sleepMinutes15,
              selected: false,
              onTap: () =>
                  controller.setSleepTimer(const Duration(minutes: 15)),
            ),
            item(
              icon: Icons.bedtime_outlined,
              label: s.sleepMinutes30,
              selected: false,
              onTap: () =>
                  controller.setSleepTimer(const Duration(minutes: 30)),
            ),
            item(
              icon: Icons.bedtime_outlined,
              label: s.sleepHour1,
              selected: false,
              onTap: () =>
                  controller.setSleepTimer(const Duration(hours: 1)),
            ),
            const Divider(height: 1),
            item(
              icon: Icons.last_page,
              label: s.sleepEndOfTrack,
              selected: state.sleepAtEndOfTrack,
              onTap: () => controller.setSleepAtEndOfTrack(true),
            ),
          ],
        ),
      ),
    );
  }
}
