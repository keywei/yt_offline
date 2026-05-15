import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/category_store.dart';
import '../../../../core/storage/video_metadata.dart';
import '../../../download/presentation/providers/download_providers.dart';
import '../../data/repositories/library_repository_impl.dart';
import '../../domain/repositories/library_repository.dart';

final categoryStoreProvider = Provider<CategoryStore>(
  (ref) => CategoryStore(ref.watch(mediaStorageProvider)),
);

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepositoryImpl(
    ref.watch(videoMetadataStoreProvider),
    ref.watch(categoryStoreProvider),
  ),
);

/// Set of section keys whose sections are currently collapsed.
final collapsedCategoriesProvider =
    StateProvider<Set<String>>((_) => <String>{});

/// Auto-invalidated whenever a download job reaches `complete` so the
/// Library list stays in sync without a manual refresh.
final libraryListProvider = FutureProvider<List<VideoMetadata>>((ref) {
  ref.listen(downloadJobsProvider, (_, next) {
    next.whenData((jobs) {
      if (jobs.any((j) => j.status.name == 'complete')) {
        ref.invalidateSelf();
      }
    });
  });
  return ref.watch(libraryRepositoryProvider).listAll();
});

/// Union of stored empty categories + categories used by videos +
/// Uncategorized. Re-fetched whenever the library list changes.
final knownCategoriesProvider = FutureProvider<List<String>>((ref) {
  // Trigger a rebuild whenever the library list changes (videos moved
  // between categories may add/remove members).
  ref.watch(libraryListProvider);
  return ref.watch(libraryRepositoryProvider).listCategories();
});
