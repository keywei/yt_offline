import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/storage/video_metadata.dart';
import '../../../download/domain/entities/download_job.dart';
import '../../../download/domain/entities/download_status.dart';
import '../../../download/presentation/providers/download_providers.dart';
import '../../../player/presentation/providers/playback_providers.dart';
import '../providers/library_providers.dart';
import '../widgets/downloaded_video_tile.dart';

const _kInProgressKey = '__in_progress__';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(libraryListProvider);
    final jobs = ref.watch(downloadJobsProvider);
    final playback = ref.watch(playbackControllerProvider);
    final collapsed = ref.watch(collapsedCategoriesProvider);
    final currentId = playback.current?.id;
    final isPlayingNow = playback.isPlaying;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(libraryListProvider),
          ),
        ],
      ),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (videos) {
          final allJobs = jobs.maybeWhen<List<DownloadJob>>(
            data: (js) => js,
            orElse: () => const <DownloadJob>[],
          );
          final activeJobs = allJobs
              .where((j) => j.status != DownloadStatus.complete)
              .toList();

          if (videos.isEmpty && activeJobs.isEmpty) {
            return const Center(
              child: Text(
                'Nothing downloaded yet.\nTap a video on Search to download.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black87),
              ),
            );
          }

          // Group by category, sort each by (position asc, downloadedAt desc).
          final grouped = <String, List<VideoMetadata>>{};
          for (final v in videos) {
            grouped.putIfAbsent(v.category, () => []).add(v);
          }
          for (final entry in grouped.entries) {
            entry.value.sort((a, b) {
              if (a.position != b.position) {
                return a.position.compareTo(b.position);
              }
              return b.downloadedAt.compareTo(a.downloadedAt);
            });
          }
          final categories = grouped.keys.toList()..sort();

          final inProgressCollapsed = collapsed.contains(_kInProgressKey);

          return ListView(
            children: [
              if (activeJobs.isNotEmpty) ...[
                _SectionHeader(
                  text: 'In progress (${activeJobs.length})',
                  collapsed: inProgressCollapsed,
                  onTap: () => _toggleCategory(ref, _kInProgressKey),
                ),
                if (!inProgressCollapsed)
                  ...activeJobs.map(
                    (j) => _ActiveJobTile(
                      job: j,
                      onPause: () =>
                          ref.read(downloadRepositoryProvider).pause(j.id),
                      onResume: () =>
                          ref.read(downloadRepositoryProvider).resume(j.id),
                      onCancel: () =>
                          ref.read(downloadRepositoryProvider).cancel(j.id),
                      onRetry: () =>
                          ref.read(downloadRepositoryProvider).retry(j.id),
                      onDismiss: () =>
                          ref.read(downloadRepositoryProvider).dismiss(j.id),
                    ),
                  ),
                const Divider(height: 1),
              ],
              for (final cat in categories) ...[
                _CategoryDropTarget(
                  category: cat,
                  onAcceptVideo: (v) => _moveTo(
                    ref,
                    video: v,
                    targetCategory: cat,
                    targetIndex: grouped[cat]!.length,
                  ),
                  child: _SectionHeader(
                    text: '$cat (${grouped[cat]!.length})',
                    collapsed: collapsed.contains(cat),
                    onTap: () => _toggleCategory(ref, cat),
                  ),
                ),
                if (!collapsed.contains(cat))
                  ...grouped[cat]!.asMap().entries.map((entry) {
                    final i = entry.key;
                    final v = entry.value;
                    return _DraggableTile(
                      meta: v,
                      onAcceptVideo: (dragged) => _moveTo(
                        ref,
                        video: dragged,
                        targetCategory: cat,
                        targetIndex: i,
                      ),
                      child: DownloadedVideoTile(
                        meta: v,
                        isCurrent: v.id == currentId,
                        isPlayingNow: isPlayingNow,
                        onTap: () =>
                            _play(context, ref, grouped[cat]!, v),
                        onDelete: () => _confirmDelete(context, ref, v),
                      ),
                    );
                  }),
              ],
            ],
          );
        },
      ),
    );
  }

  void _toggleCategory(WidgetRef ref, String key) {
    final notifier = ref.read(collapsedCategoriesProvider.notifier);
    final next = Set<String>.from(notifier.state);
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    notifier.state = next;
  }

  Future<void> _moveTo(
    WidgetRef ref, {
    required VideoMetadata video,
    required String targetCategory,
    required int targetIndex,
  }) async {
    await ref.read(libraryRepositoryProvider).move(
          videoId: video.id,
          targetCategory: targetCategory,
          targetIndex: targetIndex,
        );
    ref.invalidate(libraryListProvider);
  }

  Future<void> _play(
    BuildContext context,
    WidgetRef ref,
    List<VideoMetadata> categoryQueue,
    VideoMetadata tapped,
  ) async {
    final wasPlaying =
        ref.read(playbackControllerProvider).current != null;
    final idx = categoryQueue.indexWhere((v) => v.id == tapped.id);
    await ref
        .read(playbackControllerProvider.notifier)
        .playQueue(categoryQueue, idx);
    if (!context.mounted || wasPlaying) return;
    unawaited(context.push('/player'));
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    VideoMetadata v,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${v.title}"?'),
        content: const Text('This removes the video, subtitle, and metadata.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if ((ok ?? false) && context.mounted) {
      await ref.read(libraryRepositoryProvider).delete(v.id);
      ref.invalidate(libraryListProvider);
    }
  }
}

/// A tile that is both a drag SOURCE (long-press to lift) and a drag TARGET
/// (other tiles drop onto it → insert above this tile).
class _DraggableTile extends StatelessWidget {
  final VideoMetadata meta;
  final Widget child;
  final ValueChanged<VideoMetadata> onAcceptVideo;

  const _DraggableTile({
    required this.meta,
    required this.child,
    required this.onAcceptVideo,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<VideoMetadata>(
      onWillAcceptWithDetails: (d) => d.data.id != meta.id,
      onAcceptWithDetails: (d) => onAcceptVideo(d.data),
      builder: (context, candidate, _) {
        final hovering = candidate.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: hovering
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: LongPressDraggable<VideoMetadata>(
            data: meta,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedback: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(width: 280, child: child),
            ),
            childWhenDragging: Opacity(opacity: 0.25, child: child),
            child: child,
          ),
        );
      },
    );
  }
}

/// A drag target wrapping the section header. Dropping a video here moves
/// it to the end of that category (cross-category recategorize).
class _CategoryDropTarget extends StatelessWidget {
  final String category;
  final Widget child;
  final ValueChanged<VideoMetadata> onAcceptVideo;

  const _CategoryDropTarget({
    required this.category,
    required this.child,
    required this.onAcceptVideo,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<VideoMetadata>(
      onWillAcceptWithDetails: (d) => d.data.category != category,
      onAcceptWithDetails: (d) => onAcceptVideo(d.data),
      builder: (context, candidate, _) {
        final hovering = candidate.isNotEmpty;
        return Container(
          color: hovering
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: child,
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  final bool? collapsed;
  final VoidCallback? onTap;

  const _SectionHeader({required this.text, this.collapsed, this.onTap});

  @override
  Widget build(BuildContext context) {
    final showChevron = collapsed != null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            if (showChevron) ...[
              Icon(
                (collapsed ?? false)
                    ? Icons.chevron_right
                    : Icons.expand_more,
                size: 20,
              ),
              const SizedBox(width: 4),
            ],
            Text(text, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

class _ActiveJobTile extends StatelessWidget {
  final DownloadJob job;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  const _ActiveJobTile({
    required this.job,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.onRetry,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actions = _actionsFor(job.status);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 88,
              height: 52,
              child: Image.network(
                job.thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Colors.black12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${job.category} • ${_statusLabel(job.status)}'
                  '${job.status == DownloadStatus.running ? ' ${(job.progress * 100).toStringAsFixed(0)}%' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                _ProgressBar(status: job.status, progress: job.progress),
                if (job.error != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    job.error!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                Row(children: actions),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _actionsFor(DownloadStatus s) {
    Widget btn(IconData icon, String label, VoidCallback onTap) =>
        TextButton.icon(
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 32),
          ),
          icon: Icon(icon, size: 16),
          label: Text(label, style: const TextStyle(fontSize: 12)),
          onPressed: onTap,
        );

    return switch (s) {
      DownloadStatus.preparing => [btn(Icons.close, 'Cancel', onCancel)],
      DownloadStatus.queued || DownloadStatus.running => [
          btn(Icons.pause, 'Pause', onPause),
          btn(Icons.close, 'Cancel', onCancel),
        ],
      DownloadStatus.paused => [
          btn(Icons.play_arrow, 'Resume', onResume),
          btn(Icons.close, 'Cancel', onCancel),
        ],
      DownloadStatus.failed || DownloadStatus.canceled => [
          btn(Icons.refresh, 'Retry', onRetry),
          btn(Icons.clear, 'Dismiss', onDismiss),
        ],
      DownloadStatus.complete => const [],
    };
  }

  String _statusLabel(DownloadStatus s) => switch (s) {
        DownloadStatus.preparing => 'Resolving stream…',
        DownloadStatus.queued => 'Queued',
        DownloadStatus.running => 'Downloading',
        DownloadStatus.paused => 'Paused',
        DownloadStatus.complete => 'Complete',
        DownloadStatus.failed => 'Failed',
        DownloadStatus.canceled => 'Canceled',
      };
}

class _ProgressBar extends StatelessWidget {
  final DownloadStatus status;
  final double progress;
  const _ProgressBar({required this.status, required this.progress});

  @override
  Widget build(BuildContext context) {
    final indeterminate = status == DownloadStatus.preparing ||
        (status == DownloadStatus.queued && progress == 0);
    final value = indeterminate ? null : progress;
    final color = switch (status) {
      DownloadStatus.failed => Theme.of(context).colorScheme.error,
      DownloadStatus.canceled => Colors.grey,
      _ => null,
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 4,
        color: color,
      ),
    );
  }
}
