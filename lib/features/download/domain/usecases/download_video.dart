import '../../../../core/result/result.dart';
import '../repositories/download_repository.dart';

class DownloadVideo {
  final DownloadRepository _repo;
  const DownloadVideo(this._repo);

  Future<Result<void>> call({
    required String videoId,
    required String title,
    required String thumbnailUrl,
    required String category,
  }) =>
      _repo.enqueue(
        videoId: videoId,
        title: title,
        thumbnailUrl: thumbnailUrl,
        category: category,
      );
}
