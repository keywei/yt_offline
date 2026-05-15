import 'dart:convert';
import 'dart:io';

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
        metas.add(
          VideoMetadata.fromJson(jsonDecode(raw) as Map<String, Object?>),
        );
      } catch (_) {
        // Skip corrupt files; they'll be overwritten on next download.
      }
    }
    metas.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    return metas;
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
