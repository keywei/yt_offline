import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/media_storage.dart';
import '../../../../core/storage/video_metadata_store.dart';
import '../../../search/presentation/providers/search_providers.dart';
import '../../data/datasources/background_download_datasource.dart';
import '../../data/datasources/youtube_stream_datasource.dart';
import '../../data/repositories/download_repository_impl.dart';
import '../../domain/entities/download_job.dart';
import '../../domain/repositories/download_repository.dart';
import '../../domain/usecases/download_video.dart';

// --- Core/shared ---
final mediaStorageProvider = Provider<MediaStorage>((_) => MediaStorage());

final videoMetadataStoreProvider = Provider<VideoMetadataStore>(
  (ref) => VideoMetadataStore(ref.watch(mediaStorageProvider)),
);

// --- Data sources ---
final youtubeStreamDataSourceProvider = Provider<YoutubeStreamDataSource>(
  (ref) => YoutubeStreamDataSource(ref.watch(youtubeExplodeProvider)),
);

final backgroundDownloadDataSourceProvider =
    Provider<BackgroundDownloadDataSource>(
  (_) => BackgroundDownloadDataSource(),
);

// --- Repository (singleton; owns streams + state) ---
final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  final repo = DownloadRepositoryImpl(
    stream: ref.watch(youtubeStreamDataSourceProvider),
    downloader: ref.watch(backgroundDownloadDataSourceProvider),
    metaStore: ref.watch(videoMetadataStoreProvider),
    storage: ref.watch(mediaStorageProvider),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

// --- Use case ---
final downloadVideoUseCaseProvider = Provider<DownloadVideo>(
  (ref) => DownloadVideo(ref.watch(downloadRepositoryProvider)),
);

// --- Live list of jobs ---
final downloadJobsProvider = StreamProvider<List<DownloadJob>>(
  (ref) => ref.watch(downloadRepositoryProvider).watchAll(),
);

/// One-shot startup hook. Watch this at the root of the widget tree so the
/// app waits for `background_downloader` to be ready before showing UI.
final downloadInitializerProvider = FutureProvider<void>(
  (ref) async => ref.read(downloadRepositoryProvider).initialize(),
);
