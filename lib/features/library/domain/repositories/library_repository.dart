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
}
