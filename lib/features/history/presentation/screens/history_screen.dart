import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/strings.dart';
import '../../../../core/storage/video_metadata.dart';
import '../../../../core/storage/watch_history_store.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../../player/presentation/providers/playback_providers.dart';
import '../providers/history_providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final asyncHistory = ref.watch(watchHistoryProvider);
    final asyncLibrary = ref.watch(libraryListProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.historyTitle),
        actions: [
          asyncHistory.maybeWhen(
            data: (events) => events.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: s.clearAll,
                    icon: const Icon(Icons.delete_sweep),
                    onPressed: () => _confirmClear(context, ref),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: asyncHistory.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (events) {
          if (events.isEmpty) {
            return Center(child: Text(s.historyEmpty));
          }
          // Most recent first.
          final reversed = events.reversed.toList();
          final library = asyncLibrary.valueOrNull ?? const <VideoMetadata>[];
          return ListView.separated(
            itemCount: reversed.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = reversed[i];
              final stillInLibrary =
                  library.where((v) => v.id == e.videoId).cast<VideoMetadata?>().firstWhere(
                        (_) => true,
                        orElse: () => null,
                      );
              return _HistoryRow(
                event: e,
                library: stillInLibrary,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.historyClearTitle),
        content: Text(s.historyClearBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.clearAll),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(watchHistoryProvider.notifier).clear();
    }
  }
}

class _HistoryRow extends ConsumerWidget {
  final WatchEvent event;
  final VideoMetadata? library;
  const _HistoryRow({required this.event, required this.library});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final canResume = library != null;
    final fraction = event.duration.inMilliseconds > 0
        ? event.lastPosition.inMilliseconds / event.duration.inMilliseconds
        : 0.0;
    return ListTile(
      title: Text(
        event.title.isEmpty ? event.videoId : event.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            s.historyPlayedUpTo(
              _fmt(event.lastPosition),
              _fmt(event.duration),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _relativeTime(context, event.startedAt),
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          if (fraction > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(value: fraction.clamp(0, 1)),
            ),
        ],
      ),
      trailing: canResume
          ? IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () => _resume(ref),
            )
          : Tooltip(
              message: s.historyVideoMissing,
              child: const Icon(Icons.warning_amber_outlined),
            ),
      onTap: canResume ? () => _resume(ref) : null,
    );
  }

  Future<void> _resume(WidgetRef ref) async {
    final v = library;
    if (v == null) return;
    // Build a single-item queue: the existing playback machinery will
    // handle resume-point seeking via VideoMetadata.lastPosition, which
    // is already kept in sync by _persistPosition.
    await ref
        .read(playbackControllerProvider.notifier)
        .playQueue([v], 0);
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String _relativeTime(BuildContext context, DateTime t) {
    final s = S.of(context);
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return s.relTimeJustNow;
    if (diff.inMinutes < 60) return s.relTimeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return s.relTimeHoursAgo(diff.inHours);
    if (diff.inDays < 30) return s.relTimeDaysAgo(diff.inDays);
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }
}
