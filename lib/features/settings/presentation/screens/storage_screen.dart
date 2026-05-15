import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/strings.dart';
import '../../../../core/storage/storage_inspector.dart';
import '../../../../core/storage/video_metadata.dart';
import '../../../library/presentation/providers/library_providers.dart';

final _storageInspectorProvider = Provider((_) => StorageInspector());

final _storageReportProvider = FutureProvider<StorageReport>((ref) async {
  final videos = await ref.watch(libraryListProvider.future);
  return ref.watch(_storageInspectorProvider).scan(videos);
});

class StorageScreen extends ConsumerWidget {
  const StorageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final asyncReport = ref.watch(_storageReportProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.storageTitle)),
      body: asyncReport.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (report) => _Body(report: report),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final StorageReport report;
  const _Body({required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    if (report.videoCount == 0) {
      return Center(child: Text(s.libraryEmpty));
    }
    return ListView(
      children: [
        _Header(report: report),
        const Divider(height: 1),
        _section(context, s.storagePerCategory),
        for (final c in report.perCategory)
          ListTile(
            dense: true,
            title: Text(s.displayCategory(c.category)),
            subtitle:
                Text('${c.videoCount} • ${formatBytes(c.bytes)}'),
            trailing: SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                value: report.totalBytes == 0
                    ? 0
                    : c.bytes / report.totalBytes,
              ),
            ),
          ),
        const Divider(height: 1),
        _section(context, s.storageBiggest),
        for (final u in report.biggest)
          ListTile(
            dense: true,
            title: Text(
              u.meta.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(s.displayCategory(u.meta.category)),
            trailing: Text(formatBytes(u.bytes)),
          ),
        const Divider(height: 1),
        _section(context, s.storageCleanup),
        _WatchedCleanupTile(report: report),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _section(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge,
        ),
      );
}

class _Header extends StatelessWidget {
  final StorageReport report;
  const _Header({required this.report});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatBytes(report.totalBytes),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            s.storageUsedSummary(report.videoCount),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _WatchedCleanupTile extends ConsumerWidget {
  final StorageReport report;
  const _WatchedCleanupTile({required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final count = report.watched.length;
    if (count == 0) {
      return ListTile(
        leading: const Icon(Icons.check_circle_outline),
        title: Text(s.storageNoWatched),
      );
    }
    return ListTile(
      leading: const Icon(Icons.delete_sweep, color: Colors.red),
      title: Text(
        s.storageDeleteWatched(count, formatBytes(report.watchedBytes)),
      ),
      subtitle: Text(s.storageDeleteWatchedSubtitle),
      onTap: () => _confirmDelete(context, ref),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.storageDeleteWatchedConfirmTitle),
        content: Text(
          s.storageDeleteWatchedConfirmBody(
            report.watched.length,
            formatBytes(report.watchedBytes),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final repo = ref.read(libraryRepositoryProvider);
    for (final VideoMetadata v in report.watched) {
      await repo.delete(v.id);
    }
    // Force the storage report and library list to refresh.
    ref.invalidate(libraryListProvider);
    ref.invalidate(_storageReportProvider);
  }
}
