import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'media_storage.dart';
import 'video_metadata.dart';

/// JSON-file backed persistence for [VideoMetadata]. One file per video.
/// Trade-off vs. a DB: simpler, no migrations, atomic per-file writes,
/// good enough for hundreds of entries. Swap to Drift if scale demands.
class VideoMetadataStore {
  final MediaStorage _storage;
  const VideoMetadataStore(this._storage);

  Future<void> save(VideoMetadata meta) async {
    final file = await _storage.metadataFile(meta.id);
    await file.writeAsString(jsonEncode(meta.toJson()), flush: true);
  }

  Future<List<VideoMetadata>> listAll() async {
    final dir = await _storage.videosDir();
    final entries = await dir.list().toList();
    final metas = <VideoMetadata>[];
    for (final e in entries) {
      if (e is! File || !e.path.endsWith('.json')) continue;
      try {
        final raw = await e.readAsString();
        final original =
            VideoMetadata.fromJson(jsonDecode(raw) as Map<String, Object?>);
        // iOS rewrites the sandbox container UUID on every install (e.g.
        // `xcrun devicectl device install app` keeps Documents/ but mints a
        // new container path). The absolute `videoPath` / `subtitlePath`
        // stored before the install now point to a directory that no longer
        // exists, so playback fails even though the file is still on disk.
        // Re-derive both paths from the *current* videos dir and re-save
        // the JSON so subsequent reads start clean.
        final fixed = await _rehomePaths(original, dir);
        if (fixed.videoPath != original.videoPath ||
            fixed.subtitlePath != original.subtitlePath) {
          unawaited(save(fixed));
        }
        metas.add(fixed);
      } catch (_) {
        // Skip corrupt files; they'll be overwritten on next download.
      }
    }
    metas.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    return metas;
  }

  Future<VideoMetadata> _rehomePaths(
    VideoMetadata m,
    Directory dir,
  ) async {
    final newVideoPath = p.join(dir.path, '${m.id}.mp4');
    final subFile = File(p.join(dir.path, '${m.id}.srt'));
    final newSubtitlePath = await subFile.exists() ? subFile.path : null;
    if (newVideoPath == m.videoPath && newSubtitlePath == m.subtitlePath) {
      return m;
    }
    return VideoMetadata(
      id: m.id,
      title: m.title,
      author: m.author,
      duration: m.duration,
      thumbnailUrl: m.thumbnailUrl,
      videoPath: newVideoPath,
      subtitlePath: newSubtitlePath,
      downloadedAt: m.downloadedAt,
      category: m.category,
      position: m.position,
      lastPosition: m.lastPosition,
      lastPositionAt: m.lastPositionAt,
    );
  }

  Future<void> delete(String videoId) async {
    final files = [
      await _storage.videoFile(videoId),
      await _storage.subtitleFile(videoId),
      await _storage.metadataFile(videoId),
    ];
    for (final f in files) {
      if (await f.exists()) await f.delete();
    }
  }
}
