import 'dart:io';

import 'video_metadata.dart';

/// Aggregated disk usage for one category.
class CategoryUsage {
  final String category;
  final int videoCount;
  final int bytes;
  const CategoryUsage({
    required this.category,
    required this.videoCount,
    required this.bytes,
  });
}

/// One video's on-disk size — used for the "biggest videos" list.
class VideoUsage {
  final VideoMetadata meta;
  final int bytes;
  const VideoUsage({required this.meta, required this.bytes});
}

/// Output of [StorageInspector.scan].
class StorageReport {
  final int totalBytes;
  final int videoCount;
  final List<CategoryUsage> perCategory;
  final List<VideoUsage> biggest;
  final List<VideoMetadata> watched;
  final int watchedBytes;

  const StorageReport({
    required this.totalBytes,
    required this.videoCount,
    required this.perCategory,
    required this.biggest,
    required this.watched,
    required this.watchedBytes,
  });

  static const empty = StorageReport(
    totalBytes: 0,
    videoCount: 0,
    perCategory: [],
    biggest: [],
    watched: [],
    watchedBytes: 0,
  );
}

/// Walks the library on disk and returns a [StorageReport] without
/// allocating per-file work elsewhere. Pure Dart + `dart:io` — same on
/// Android and iOS.
class StorageInspector {
  /// Number of "biggest videos" rows to include in the report.
  static const _biggestRows = 5;

  /// A video counts as "watched" once its persisted resume fraction goes
  /// past [VideoMetadata.finishedThreshold].
  static const _watchedThreshold = VideoMetadata.finishedThreshold;

  Future<StorageReport> scan(List<VideoMetadata> all) async {
    if (all.isEmpty) return StorageReport.empty;

    final perCategoryBytes = <String, int>{};
    final perCategoryCount = <String, int>{};
    final usages = <VideoUsage>[];
    final watched = <VideoMetadata>[];
    var total = 0;
    var watchedBytes = 0;

    for (final v in all) {
      final size = await _sizeOf(v);
      total += size;
      usages.add(VideoUsage(meta: v, bytes: size));
      perCategoryBytes.update(v.category, (n) => n + size, ifAbsent: () => size);
      perCategoryCount.update(v.category, (n) => n + 1, ifAbsent: () => 1);
      if (v.watchedFraction >= _watchedThreshold) {
        watched.add(v);
        watchedBytes += size;
      }
    }

    final perCategory = perCategoryBytes.entries
        .map((e) => CategoryUsage(
              category: e.key,
              videoCount: perCategoryCount[e.key] ?? 0,
              bytes: e.value,
            ))
        .toList()
      ..sort((a, b) => b.bytes.compareTo(a.bytes));

    final biggest = usages.toList()
      ..sort((a, b) => b.bytes.compareTo(a.bytes));

    return StorageReport(
      totalBytes: total,
      videoCount: all.length,
      perCategory: perCategory,
      biggest: biggest.take(_biggestRows).toList(),
      watched: watched,
      watchedBytes: watchedBytes,
    );
  }

  Future<int> _sizeOf(VideoMetadata v) async {
    var total = 0;
    total += await _safeSize(v.videoPath);
    final sub = v.subtitlePath;
    if (sub != null) total += await _safeSize(sub);
    return total;
  }

  Future<int> _safeSize(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) return 0;
      return await f.length();
    } catch (_) {
      return 0;
    }
  }
}

/// Pretty 2 GB / 940 MB / 12.3 MB formatting. Uses base-1024.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var v = bytes.toDouble();
  var i = -1;
  do {
    v /= 1024;
    i++;
  } while (v >= 1024 && i < units.length - 1);
  if (v >= 100) return '${v.toStringAsFixed(0)} ${units[i]}';
  if (v >= 10) return '${v.toStringAsFixed(1)} ${units[i]}';
  return '${v.toStringAsFixed(2)} ${units[i]}';
}
