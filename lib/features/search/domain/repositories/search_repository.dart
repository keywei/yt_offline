import '../../../../core/result/result.dart';
import '../entities/video_page.dart';

/// Domain contract for searching videos with pagination.
/// The repository owns the pagination cursor internally; callers
/// just see [VideoPage] with `hasMore`.
abstract interface class SearchRepository {
  Future<Result<VideoPage>> search(String query);
  Future<Result<VideoPage>> loadMore();
}
