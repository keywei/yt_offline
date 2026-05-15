import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../../core/i18n/strings.dart';
import '../../../../core/storage/video_metadata.dart';
import '../../../download/domain/entities/download_job.dart';
import '../../../download/domain/entities/download_status.dart';
import '../../../download/presentation/providers/download_providers.dart';
import '../../../player/presentation/providers/playback_providers.dart';
import '../../../player/presentation/state/now_playing_provider.dart';
import '../providers/library_providers.dart';
import '../widgets/downloaded_video_tile.dart';

const _kInProgressKey = '__in_progress__';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _selectionMode = false;
  final _selected = <String>{};

  void _enterSelection(VideoMetadata v) {
    setState(() {
      _selectionMode = true;
      _selected.add(v.id);
    });
  }

  void _toggleSelection(VideoMetadata v) {
    setState(() {
      if (_selected.contains(v.id)) {
        _selected.remove(v.id);
        if (_selected.isEmpty) _selectionMode = false;
      } else {
        _selected.add(v.id);
      }
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selected.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(libraryListProvider);
    final jobs = ref.watch(downloadJobsProvider);
    final playback = ref.watch(playbackControllerProvider);
    final collapsed = ref.watch(collapsedCategoriesProvider);
    final currentId = playback.current?.id;
    final isPlayingNow = playback.isPlaying;

    return Scaffold(
      appBar: _buildAppBar(),
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

          // Include empty (user-created) categories from the category list.
          final known = ref.watch(knownCategoriesProvider).maybeWhen(
                data: (l) => l,
                orElse: () => <String>[],
              );
          final allCategories = {
            ...grouped.keys,
            ...known,
          }.toList()
            ..sort();

          // Only Uncategorized always renders even if empty + only category;
          // hide totally empty non-Uncategorized categories when there are
          // no videos at all (looks cleaner on first launch).
          final hasAnything =
              videos.isNotEmpty || activeJobs.isNotEmpty || known.isNotEmpty;
          final s = S.of(context);
          if (!hasAnything) {
            return Center(
              child: Text(
                s.libraryEmpty,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black87),
              ),
            );
          }

          final inProgressCollapsed = collapsed.contains(_kInProgressKey);

          return ListView(
            children: [
              if (activeJobs.isNotEmpty) ...[
                _SectionHeader(
                  text: s.inProgressHeader(activeJobs.length),
                  collapsed: inProgressCollapsed,
                  onTap: () => _toggleCollapsed(_kInProgressKey),
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
              for (final cat in allCategories) ...[
                _CategoryDropTarget(
                  category: cat,
                  enabled: !_selectionMode,
                  onAcceptVideo: (v) => _moveTo(
                    video: v,
                    targetCategory: cat,
                    targetIndex: (grouped[cat] ?? const []).length,
                  ),
                  child: _SectionHeader(
                    text: '$cat (${(grouped[cat] ?? const []).length})',
                    collapsed: collapsed.contains(cat),
                    onTap: () => _toggleCollapsed(cat),
                    onLongPress: cat == VideoMetadata.defaultCategory
                        ? null
                        : () => _showCategoryMenu(cat),
                  ),
                ),
                if (!collapsed.contains(cat)) ...[
                  ...(grouped[cat] ?? const []).asMap().entries.map((entry) {
                    final i = entry.key;
                    final v = entry.value;
                    return _libraryTile(
                      v: v,
                      categoryIndex: i,
                      category: cat,
                      categoryList: grouped[cat] ?? const [],
                      currentId: currentId,
                      isPlayingNow: isPlayingNow,
                    );
                  }),
                  // Drop here to append to the end of this category.
                  if (!_selectionMode &&
                      (grouped[cat] ?? const []).isNotEmpty)
                    _TrailingDropZone(
                      onAcceptVideo: (dragged) {
                        final list = grouped[cat] ?? const [];
                        var target = list.length;
                        if (dragged.category == cat) {
                          // Source is in the same category → after removal,
                          // length shrinks by 1; clamping inside repo handles
                          // it, but keep the math explicit.
                          target = list.length - 1;
                        }
                        _moveTo(
                          video: dragged,
                          targetCategory: cat,
                          targetIndex: target,
                        );
                      },
                    ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final s = S.of(context);
    if (_selectionMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitSelection,
        ),
        title: Text(s.selectedN(_selected.length)),
        actions: [
          IconButton(
            tooltip: s.moveToCategory,
            icon: const Icon(Icons.drive_file_move_outline),
            onPressed: _batchMove,
          ),
        ],
      );
    }
    return AppBar(
      title: Text(s.tabLibrary),
      actions: [
        IconButton(
          tooltip: s.newCategory,
          icon: const Icon(Icons.create_new_folder_outlined),
          onPressed: _addCategory,
        ),
        IconButton(
          tooltip: s.collapseExpandAll,
          icon: const Icon(Icons.unfold_less),
          onPressed: _toggleAllCollapsed,
        ),
        IconButton(
          tooltip: s.refresh,
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(libraryListProvider),
        ),
      ],
    );
  }

  /// Gather every section key currently rendered (In progress + each
  /// category, including empty user-created ones) and either collapse all
  /// of them or — if they're already all collapsed — expand them all.
  void _toggleAllCollapsed() {
    final keys = <String>{};
    final jobs = ref.read(downloadJobsProvider).value ?? const [];
    if (jobs.any((j) => j.status != DownloadStatus.complete)) {
      keys.add(_kInProgressKey);
    }
    final videos = ref.read(libraryListProvider).value ?? const [];
    keys.addAll(videos.map((v) => v.category));
    final known = ref.read(knownCategoriesProvider).value ?? const [];
    keys.addAll(known);
    if (keys.isEmpty) return;

    final notifier = ref.read(collapsedCategoriesProvider.notifier);
    final alreadyAllCollapsed = keys.every(notifier.state.contains);
    notifier.state = alreadyAllCollapsed ? <String>{} : keys;
  }

  Widget _libraryTile({
    required VideoMetadata v,
    required int categoryIndex,
    required String category,
    required List<VideoMetadata> categoryList,
    required String? currentId,
    required bool isPlayingNow,
  }) {
    void onPlay() {
      _play(List<VideoMetadata>.from(categoryList), v);
    }

    final tile = DownloadedVideoTile(
      meta: v,
      isCurrent: v.id == currentId,
      isPlayingNow: isPlayingNow,
      selected: _selectionMode ? _selected.contains(v.id) : null,
      onTap: () => _selectionMode ? _toggleSelection(v) : onPlay(),
      // Long-press the thumbnail to enter batch selection.
      onLongPressThumbnail:
          _selectionMode ? null : () => _enterSelection(v),
      // Long-press the body (title/subtitle) to start a drag for reordering.
      bodyWrapper: _selectionMode
          ? null
          : (child) => LongPressDraggable<VideoMetadata>(
                data: v,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: _dragPreview(v),
                childWhenDragging: Opacity(opacity: 0.3, child: child),
                child: child,
              ),
    );

    if (_selectionMode) return tile;

    return _DropTarget(
      meta: v,
      onAcceptVideo: (dragged) {
        // Caller passes `categoryIndex` which is the rendered position of
        // the target tile. The repo removes the source from its current
        // place first, so if the source is in the same category AND comes
        // BEFORE the target, the target's post-removal index is one less.
        var adjusted = categoryIndex;
        if (dragged.category == category) {
          final sourcePos =
              categoryList.indexWhere((m) => m.id == dragged.id);
          if (sourcePos >= 0 && sourcePos < categoryIndex) {
            adjusted -= 1;
          }
        }
        _moveTo(
          video: dragged,
          targetCategory: category,
          targetIndex: adjusted,
        );
      },
      child: Slidable(
        key: ValueKey('lib-${v.id}'),
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.22,
          children: [
            SlidableAction(
              onPressed: (_) async {
                await ref.read(libraryRepositoryProvider).delete(v.id);
                ref.invalidate(libraryListProvider);
              },
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: S.of(context).delete,
            ),
          ],
        ),
        child: tile,
      ),
    );
  }

  Widget _dragPreview(VideoMetadata v) => Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Icon(Icons.drag_indicator, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  v.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );

  void _toggleCollapsed(String key) {
    final notifier = ref.read(collapsedCategoriesProvider.notifier);
    final next = Set<String>.from(notifier.state);
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    notifier.state = next;
  }

  Future<void> _moveTo({
    required VideoMetadata video,
    required String targetCategory,
    required int targetIndex,
  }) async {
    await ref.read(libraryRepositoryProvider).move(
          videoId: video.id,
          targetCategory: targetCategory,
          targetIndex: targetIndex,
        );
    // PlaybackController listens to libraryListProvider and re-syncs the
    // queue automatically on this invalidation — no need to push here.
    ref.invalidate(libraryListProvider);
  }

  Future<void> _play(
    List<VideoMetadata> categoryQueue,
    VideoMetadata tapped,
  ) async {
    final wasPlaying =
        ref.read(playbackControllerProvider).current != null;
    final idx = categoryQueue.indexWhere((v) => v.id == tapped.id);
    await ref
        .read(playbackControllerProvider.notifier)
        .playQueue(categoryQueue, idx);
    if (!mounted || wasPlaying) return;
    // Auto-expand the now-playing overlay on the first play of a session.
    ref.read(nowPlayingExpandedProvider.notifier).state = true;
  }

  // ---- Category CRUD ----

  Future<void> _addCategory() async {
    final s = S.of(context);
    final name = await _showNameDialog(title: s.newCategory);
    if (name == null || name.isEmpty) return;
    await ref.read(libraryRepositoryProvider).addCategory(name);
    ref.invalidate(libraryListProvider);
  }

  void _showCategoryMenu(String category) {
    final s = S.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(s.renameCategory),
              onTap: () {
                Navigator.of(ctx).pop();
                _renameCategory(category);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(
                s.deleteCategory,
                style: const TextStyle(color: Colors.red),
              ),
              subtitle: Text(s.videosMoveToUncategorised),
              onTap: () {
                Navigator.of(ctx).pop();
                _deleteCategory(category);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameCategory(String oldName) async {
    final s = S.of(context);
    final newName = await _showNameDialog(
      title: s.renameOf(oldName),
      initial: oldName,
    );
    if (newName == null || newName.isEmpty || newName == oldName) return;
    await ref
        .read(libraryRepositoryProvider)
        .renameCategory(oldName, newName);
    ref.invalidate(libraryListProvider);
  }

  Future<void> _deleteCategory(String name) async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteCategoryConfirm(name)),
        content: Text(s.deleteCategoryBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await ref.read(libraryRepositoryProvider).deleteCategory(name);
      ref.invalidate(libraryListProvider);
    }
  }

  Future<String?> _showNameDialog({
    required String title,
    String initial = '',
  }) {
    final s = S.of(context);
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: s.name),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ---- Batch move ----

  Future<void> _batchMove() async {
    if (_selected.isEmpty) return;
    final target = await _pickCategoryForMove();
    if (target == null) return;
    final repo = ref.read(libraryRepositoryProvider);
    // Snapshot the selection because UI may exit mode before async finishes.
    final ids = _selected.toList();
    for (final id in ids) {
      final size = (await repo.listAll())
          .where((v) => v.category == target)
          .length;
      await repo.move(
        videoId: id,
        targetCategory: target,
        targetIndex: size,
      );
    }
    ref.invalidate(libraryListProvider);
    _exitSelection();
  }

  Future<String?> _pickCategoryForMove() async {
    final categoriesAsync = ref.read(knownCategoriesProvider);
    final categories = categoriesAsync.maybeWhen(
      data: (l) => l,
      orElse: () => [VideoMetadata.defaultCategory],
    );
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                S.of(ctx).moveNVideosTo(_selected.length),
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            ...categories.map(
              (c) => ListTile(
                leading: Icon(
                  c == VideoMetadata.defaultCategory
                      ? Icons.inbox_outlined
                      : Icons.folder_outlined,
                ),
                title: Text(c),
                onTap: () => Navigator.of(ctx).pop(c),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A thin strip below the last tile of a category. Dropping here appends
/// the dragged video to the END of the category (since per-tile drop only
/// inserts ABOVE its tile, the very last position is unreachable without it).
class _TrailingDropZone extends StatelessWidget {
  final ValueChanged<VideoMetadata> onAcceptVideo;
  const _TrailingDropZone({required this.onAcceptVideo});

  @override
  Widget build(BuildContext context) {
    return DragTarget<VideoMetadata>(
      onAcceptWithDetails: (d) => onAcceptVideo(d.data),
      builder: (context, candidate, _) {
        final hovering = candidate.isNotEmpty;
        return Container(
          height: 28,
          margin: const EdgeInsets.only(bottom: 4),
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
        );
      },
    );
  }
}

/// Drop-only wrapper: receives other tiles dropped onto it (insert above).
/// The drag SOURCE lives inside the tile body (long-press the text area).
class _DropTarget extends StatelessWidget {
  final VideoMetadata meta;
  final Widget child;
  final ValueChanged<VideoMetadata> onAcceptVideo;

  const _DropTarget({
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
          child: child,
        );
      },
    );
  }
}

class _CategoryDropTarget extends StatelessWidget {
  final String category;
  final bool enabled;
  final Widget child;
  final ValueChanged<VideoMetadata> onAcceptVideo;

  const _CategoryDropTarget({
    required this.category,
    required this.enabled,
    required this.child,
    required this.onAcceptVideo,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
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
  final VoidCallback? onLongPress;

  const _SectionHeader({
    required this.text,
    this.collapsed,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final showChevron = collapsed != null;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
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
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            if (onLongPress != null)
              const Icon(Icons.more_vert, size: 16, color: Colors.black38),
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
    final s = S.of(context);
    final theme = Theme.of(context);
    final actions = _actionsFor(s, job.status);

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
                  '${job.category} • ${_statusLabel(s, job.status)}'
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

  List<Widget> _actionsFor(S s, DownloadStatus status) {
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

    return switch (status) {
      DownloadStatus.preparing => [btn(Icons.close, s.cancel, onCancel)],
      DownloadStatus.queued || DownloadStatus.running => [
          btn(Icons.pause, s.pause, onPause),
          btn(Icons.close, s.cancel, onCancel),
        ],
      DownloadStatus.paused => [
          btn(Icons.play_arrow, s.resume, onResume),
          btn(Icons.close, s.cancel, onCancel),
        ],
      DownloadStatus.failed || DownloadStatus.canceled => [
          btn(Icons.refresh, s.retry, onRetry),
          btn(Icons.clear, s.dismiss, onDismiss),
        ],
      DownloadStatus.complete => const [],
    };
  }

  String _statusLabel(S s, DownloadStatus status) => switch (status) {
        DownloadStatus.preparing => s.statusPreparing,
        DownloadStatus.queued => s.statusQueued,
        DownloadStatus.running => s.statusRunning,
        DownloadStatus.paused => s.statusPaused,
        DownloadStatus.complete => s.statusComplete,
        DownloadStatus.failed => s.statusFailed,
        DownloadStatus.canceled => s.statusCanceled,
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
