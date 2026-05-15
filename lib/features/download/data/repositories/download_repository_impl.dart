import 'dart:async';

import 'package:background_downloader/background_downloader.dart' as bg;

import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/storage/media_storage.dart';
import '../../../../core/storage/video_metadata.dart';
import '../../../../core/storage/video_metadata_store.dart';
import '../../domain/entities/download_job.dart';
import '../../domain/entities/download_status.dart';
import '../../domain/repositories/download_repository.dart';
import '../datasources/background_download_datasource.dart';
import '../datasources/youtube_stream_datasource.dart';

/// Orchestrates the two phases of a download:
///   A. Resolve stream URL + captions (youtube_explode_dart). Tracked under
///      a synthetic `prep:` job id so the UI can show progress / a Cancel
///      button while the HTTP call is in flight.
///   B. Enqueue the binary download into background_downloader. The job
///      gets re-keyed to the taskId. Status updates come from the BG stream.
class DownloadRepositoryImpl implements DownloadRepository {
  final YoutubeStreamDataSource _stream;
  final BackgroundDownloadDataSource _downloader;
  final VideoMetadataStore _metaStore;
  final MediaStorage _storage;

  final _jobs = <String, DownloadJob>{};
  final _pendingMeta = <String, VideoMetadata>{};
  final _cancelRequested = <String>{};
  final _jobsController = StreamController<List<DownloadJob>>.broadcast();
  StreamSubscription<bg.TaskUpdate>? _updatesSub;

  DownloadRepositoryImpl({
    required YoutubeStreamDataSource stream,
    required BackgroundDownloadDataSource downloader,
    required VideoMetadataStore metaStore,
    required MediaStorage storage,
  })  : _stream = stream,
        _downloader = downloader,
        _metaStore = metaStore,
        _storage = storage;

  @override
  Future<void> initialize() async {
    await _downloader.initialize();
    _updatesSub = _downloader.updates.listen(_handleUpdate);
  }

  void dispose() {
    _updatesSub?.cancel();
    _jobsController.close();
  }

  @override
  Stream<List<DownloadJob>> watchAll() => _jobsController.stream;

  @override
  Future<Result<void>> enqueue({
    required String videoId,
    required String title,
    required String thumbnailUrl,
    required String category,
  }) async {
    // Phase A: insert a `preparing` job synchronously so the UI can show it.
    final prepId = 'prep:$videoId:${DateTime.now().microsecondsSinceEpoch}';
    _jobs[prepId] = DownloadJob(
      id: prepId,
      videoId: videoId,
      title: title,
      thumbnailUrl: thumbnailUrl,
      category: category,
      status: DownloadStatus.preparing,
    );
    _emit();

    try {
      final resolved = await _stream.resolve(videoId);

      // User hit Cancel while we were resolving.
      if (_cancelRequested.remove(prepId)) {
        _jobs[prepId] = _jobs[prepId]!.copyWith(
          status: DownloadStatus.canceled,
        );
        _emit();
        return const Ok(null);
      }

      String? subtitlePath;
      if (resolved.subtitleSrt != null) {
        final file = await _storage.subtitleFile(videoId);
        await file.writeAsString(resolved.subtitleSrt!, flush: true);
        subtitlePath = file.path;
      }

      // Phase B: hand off to background_downloader.
      final taskId = await _downloader.enqueue(
        url: resolved.streamUrl,
        filename: '$videoId.mp4',
        subDirectory: _storage.videosSubDir,
      );

      // Re-key prep job to the bg taskId so future status updates land here.
      final prepJob = _jobs.remove(prepId)!;
      _jobs[taskId] = prepJob.copyWith(
        id: taskId,
        status: DownloadStatus.queued,
      );

      final videoFile = await _storage.videoFile(videoId);
      _pendingMeta[taskId] = VideoMetadata(
        id: videoId,
        title: resolved.title,
        author: resolved.author,
        duration: resolved.duration,
        thumbnailUrl: thumbnailUrl,
        videoPath: videoFile.path,
        subtitlePath: subtitlePath,
        downloadedAt: DateTime.now(),
        category: category,
      );

      _emit();
      return const Ok(null);
    } catch (e) {
      // Mark the prep job as failed so the UI can offer Retry / Dismiss.
      final existing = _jobs[prepId];
      if (existing != null) {
        _jobs[prepId] = existing.copyWith(
          status: DownloadStatus.failed,
          error: e.toString(),
        );
        _emit();
      }
      return Err(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> cancel(String jobId) async {
    final job = _jobs[jobId];
    if (job == null) return const Ok(null);

    if (job.status == DownloadStatus.preparing) {
      // Can't abort the in-flight HTTP, but flag it; we'll drop the result.
      _cancelRequested.add(jobId);
      return const Ok(null);
    }

    try {
      await _downloader.cancel(jobId);
      _pendingMeta.remove(jobId);
      return const Ok(null);
    } catch (e) {
      return Err(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> pause(String jobId) async {
    final job = _jobs[jobId];
    if (job == null) return const Ok(null);
    // `preparing` has no underlying task to pause; treat Pause as Cancel.
    if (job.status == DownloadStatus.preparing) return cancel(jobId);
    try {
      await _downloader.pause(jobId);
      return const Ok(null);
    } catch (e) {
      return Err(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> resume(String jobId) async {
    try {
      await _downloader.resume(jobId);
      return const Ok(null);
    } catch (e) {
      return Err(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> retry(String jobId) async {
    final job = _jobs.remove(jobId);
    _pendingMeta.remove(jobId);
    if (job == null) return const Ok(null);
    _emit();
    return enqueue(
      videoId: job.videoId,
      title: job.title,
      thumbnailUrl: job.thumbnailUrl,
      category: job.category,
    );
  }

  @override
  void dismiss(String jobId) {
    if (_jobs.remove(jobId) != null) {
      _pendingMeta.remove(jobId);
      _emit();
    }
  }

  void _handleUpdate(bg.TaskUpdate update) {
    final taskId = update.task.taskId;
    final existing = _jobs[taskId];
    if (existing == null) return;

    DownloadJob updated = existing;
    if (update is bg.TaskStatusUpdate) {
      updated = existing.copyWith(status: _mapStatus(update.status));
      if (update.status == bg.TaskStatus.complete) {
        final meta = _pendingMeta.remove(taskId);
        if (meta != null) {
          unawaited(_metaStore.save(meta));
        }
      } else if (update.status == bg.TaskStatus.canceled ||
          update.status == bg.TaskStatus.failed) {
        _pendingMeta.remove(taskId);
      }
    } else if (update is bg.TaskProgressUpdate) {
      updated = existing.copyWith(progress: update.progress.clamp(0.0, 1.0));
    }
    _jobs[taskId] = updated;
    _emit();
  }

  DownloadStatus _mapStatus(bg.TaskStatus s) => switch (s) {
        bg.TaskStatus.enqueued => DownloadStatus.queued,
        bg.TaskStatus.running => DownloadStatus.running,
        bg.TaskStatus.paused => DownloadStatus.paused,
        bg.TaskStatus.complete => DownloadStatus.complete,
        bg.TaskStatus.canceled => DownloadStatus.canceled,
        bg.TaskStatus.failed ||
        bg.TaskStatus.notFound ||
        bg.TaskStatus.waitingToRetry =>
          DownloadStatus.failed,
      };

  void _emit() {
    _jobsController.add(_jobs.values.toList(growable: false));
  }
}
