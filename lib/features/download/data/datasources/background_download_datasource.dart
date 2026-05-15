import 'package:background_downloader/background_downloader.dart';

/// Thin wrapper over `background_downloader` so the repository can be
/// written against a small surface area (and faked in tests).
class BackgroundDownloadDataSource {
  final FileDownloader _downloader = FileDownloader();

  Stream<TaskUpdate> get updates => _downloader.updates;

  Future<void> initialize() async {
    await _downloader.start();
  }

  /// Returns the taskId so callers can correlate progress updates.
  Future<String> enqueue({
    required String url,
    required String filename,
    required String subDirectory,
  }) async {
    final task = DownloadTask(
      url: url,
      filename: filename,
      baseDirectory: BaseDirectory.applicationDocuments,
      directory: subDirectory,
      updates: Updates.statusAndProgress,
      allowPause: true,
    );
    final ok = await _downloader.enqueue(task);
    if (!ok) {
      throw StateError('background_downloader rejected enqueue');
    }
    return task.taskId;
  }

  Future<void> cancel(String taskId) =>
      _downloader.cancelTaskWithId(taskId);

  Future<void> pause(String taskId) async {
    final task = await _downloader.taskForId(taskId);
    if (task is DownloadTask) await _downloader.pause(task);
  }

  Future<void> resume(String taskId) async {
    final task = await _downloader.taskForId(taskId);
    if (task is DownloadTask) await _downloader.resume(task);
  }
}
