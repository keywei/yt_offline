import '../../../../core/result/result.dart';
import '../entities/download_job.dart';

abstract interface class DownloadRepository {
  Future<void> initialize();

  Future<Result<void>> enqueue({
    required String videoId,
    required String title,
    required String thumbnailUrl,
    required String category,
  });

  Future<Result<void>> cancel(String jobId);
  Future<Result<void>> pause(String jobId);
  Future<Result<void>> resume(String jobId);

  /// Re-enqueue a failed / canceled job using its stored metadata.
  /// Removes the old entry on success.
  Future<Result<void>> retry(String jobId);

  /// Remove a terminal job entry from the live list. No I/O.
  void dismiss(String jobId);

  /// Live snapshot of all active + recently terminal jobs.
  Stream<List<DownloadJob>> watchAll();
}
