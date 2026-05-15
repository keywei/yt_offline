import '../../../../core/result/result.dart';
import '../entities/video_page.dart';
import '../repositories/search_repository.dart';

class SearchVideos {
  final SearchRepository _repo;
  const SearchVideos(this._repo);

  Future<Result<VideoPage>> call(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return Future.value(const Ok(VideoPage(items: [], hasMore: false)));
    }
    return _repo.search(trimmed);
  }
}
