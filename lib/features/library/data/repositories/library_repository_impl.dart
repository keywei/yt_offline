import '../../../../core/storage/category_store.dart';
import '../../../../core/storage/video_metadata.dart';
import '../../../../core/storage/video_metadata_store.dart';
import '../../domain/repositories/library_repository.dart';

class LibraryRepositoryImpl implements LibraryRepository {
  final VideoMetadataStore _store;
  final CategoryStore _categories;
  const LibraryRepositoryImpl(this._store, this._categories);

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

    final targetList = all
        .where((v) => v.category == targetCategory && v.id != videoId)
        .toList()
      ..sort((a, b) {
        if (a.position != b.position) return a.position.compareTo(b.position);
        return b.downloadedAt.compareTo(a.downloadedAt);
      });

    final clamped = targetIndex.clamp(0, targetList.length);
    targetList.insert(clamped, source);

    for (var i = 0; i < targetList.length; i++) {
      final v = targetList[i];
      final needsUpdate = v.position != i || v.category != targetCategory;
      if (needsUpdate) {
        await _store.save(v.copyWith(category: targetCategory, position: i));
      }
    }
  }

  // ---- Category CRUD ----

  @override
  Future<List<String>> listCategories() async {
    final stored = await _categories.list();
    final videos = await _store.listAll();
    final fromVideos = videos.map((v) => v.category).toSet();
    final all = {VideoMetadata.defaultCategory, ...stored, ...fromVideos};
    final list = all.toList()..sort();
    return list;
  }

  @override
  Future<void> addCategory(String name) => _categories.add(name);

  @override
  Future<void> renameCategory(String oldName, String newName) async {
    if (oldName == VideoMetadata.defaultCategory) return;
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == oldName) return;
    await _categories.rename(oldName, trimmed);
    final videos = await _store.listAll();
    for (final v in videos.where((v) => v.category == oldName)) {
      await _store.save(v.copyWith(category: trimmed));
    }
  }

  @override
  Future<void> deleteCategory(String name) async {
    if (name == VideoMetadata.defaultCategory) return;
    await _categories.remove(name);
    final videos = await _store.listAll();
    for (final v in videos.where((v) => v.category == name)) {
      await _store.save(v.copyWith(category: VideoMetadata.defaultCategory));
    }
  }
}
