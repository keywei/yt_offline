import '../../../../core/storage/video_metadata.dart';

abstract interface class LibraryRepository {
  Future<List<VideoMetadata>> listAll();
  Future<void> delete(String videoId);

  /// Move a video into `targetCategory` at `targetIndex` (0-based position
  /// in the target category's ordered list). Renumbers `position` fields
  /// inside the affected category. Pass `targetIndex` = current category
  /// size to append.
  Future<void> move({
    required String videoId,
    required String targetCategory,
    required int targetIndex,
  });

  // ---- Category CRUD ----

  /// Categories that exist either because the user pre-created them or
  /// because a video uses them. Always includes [VideoMetadata.defaultCategory].
  Future<List<String>> listCategories();

  Future<void> addCategory(String name);

  /// Rename `oldName` → `newName`. All videos with category == `oldName`
  /// are updated. No-op for the default Uncategorized category.
  Future<void> renameCategory(String oldName, String newName);

  /// Delete `name` and move all its videos to Uncategorized. No-op for
  /// the default Uncategorized category.
  Future<void> deleteCategory(String name);
}
