import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/video_metadata.dart';
import '../../../download/presentation/providers/download_providers.dart';
import '../../data/repositories/library_repository_impl.dart';
import '../../domain/repositories/library_repository.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepositoryImpl(ref.watch(videoMetadataStoreProvider)),
);

/// Set of category names whose sections are currently collapsed.
final collapsedCategoriesProvider =
    StateProvider<Set<String>>((_) => <String>{});

/// Auto-invalidated whenever a download job reaches `complete` so the
/// Library list stays in sync without a manual refresh.
final libraryListProvider = FutureProvider<List<VideoMetadata>>((ref) {
  ref.listen(downloadJobsProvider, (_, next) {
    next.whenData((jobs) {
      // Any newly-complete job means a new metadata.json on disk.
      if (jobs.any((j) => j.status.name == 'complete')) {
        ref.invalidateSelf();
      }
    });
  });
  return ref.watch(libraryRepositoryProvider).listAll();
});
