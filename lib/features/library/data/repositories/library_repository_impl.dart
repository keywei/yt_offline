import '../../../../core/storage/video_metadata.dart';
import '../../../../core/storage/video_metadata_store.dart';
import '../../domain/repositories/library_repository.dart';

class LibraryRepositoryImpl implements LibraryRepository {
  final VideoMetadataStore _store;
  const LibraryRepositoryImpl(this._store);

  @override
  Future<List<VideoMetadata>> listAll() => _store.listAll();

  @override
  Future<void> delete(String videoId) => _store.delete(videoId);

  @override
  Future<void> move({
    required String videoId,
    required String targetCategory,
    required int targetIndex,
  }) async {
    final all = await _store.listAll();
    final source = all.firstWhere((v) => v.id == videoId);

    // Build target category's ordered list (excluding the moving video).
    final targetList = all
        .where((v) => v.category == targetCategory && v.id != videoId)
        .toList()
      ..sort((a, b) {
        if (a.position != b.position) return a.position.compareTo(b.position);
        return b.downloadedAt.compareTo(a.downloadedAt);
      });

    final clamped = targetIndex.clamp(0, targetList.length);
    targetList.insert(clamped, source);

    // Renumber the target category to make positions contiguous + reflect
    // the new category for the moved item.
    for (var i = 0; i < targetList.length; i++) {
      final v = targetList[i];
      final needsUpdate = v.position != i || v.category != targetCategory;
      if (needsUpdate) {
        await _store.save(v.copyWith(category: targetCategory, position: i));
      }
    }
  }
}
