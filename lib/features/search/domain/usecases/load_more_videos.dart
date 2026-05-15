import '../../../../core/result/result.dart';
import '../entities/video_page.dart';
import '../repositories/search_repository.dart';

class LoadMoreVideos {
  final SearchRepository _repo;
  const LoadMoreVideos(this._repo);

  Future<Result<VideoPage>> call() => _repo.loadMore();
}
