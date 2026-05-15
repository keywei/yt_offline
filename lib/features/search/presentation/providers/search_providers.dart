import 'package:flutter/material.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../data/datasources/youtube_search_remote_datasource.dart';
import '../../data/repositories/search_repository_impl.dart';
import '../../domain/entities/search_filters.dart';
import '../../domain/repositories/search_repository.dart';
import '../../domain/usecases/load_more_videos.dart';
import '../../domain/usecases/search_videos.dart';
import '../state/search_state.dart';

final youtubeExplodeProvider = Provider<YoutubeExplode>((ref) {
  final yt = YoutubeExplode();
  ref.onDispose(yt.close);
  return yt;
});

final searchRemoteDataSourceProvider =
    Provider<YoutubeSearchRemoteDataSource>(
  (ref) => YoutubeSearchRemoteDataSource(ref.watch(youtubeExplodeProvider)),
);

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepositoryImpl(ref.watch(searchRemoteDataSourceProvider)),
);

final searchVideosUseCaseProvider = Provider<SearchVideos>(
  (ref) => SearchVideos(ref.watch(searchRepositoryProvider)),
);

final loadMoreVideosUseCaseProvider = Provider<LoadMoreVideos>(
  (ref) => LoadMoreVideos(ref.watch(searchRepositoryProvider)),
);

/// Session-scoped filters (no persistence — the HANDOVER spec calls for
/// "remembers last selection within the session"). Lives outside
/// [SearchController] so the filter sheet can read/write it without
/// triggering a re-search on every keystroke.
class SearchFiltersController extends Notifier<SearchFilters> {
  @override
  SearchFilters build() => SearchFilters.none;

  void update(SearchFilters next) => state = next;
  void clear() => state = SearchFilters.none;
}

final searchFiltersProvider =
    NotifierProvider<SearchFiltersController, SearchFilters>(
  SearchFiltersController.new,
);

class SearchController extends Notifier<SearchState> {
  String _lastQuery = '';

  @override
  SearchState build() {
    // Re-run the last query whenever the filter selection changes so the
    // user sees the new results without having to retype.
    ref.listen<SearchFilters>(searchFiltersProvider, (prev, next) {
      if (prev == null || prev == next) return;
      if (_lastQuery.isEmpty) return;
      search(_lastQuery);
    });
    return const SearchInitial();
  }

  Future<void> search(String query) async {
    final trimmed = query.trim();
    _lastQuery = trimmed;
    debugPrint('[search] start: "$trimmed"');
    state = const SearchLoading();
    final filters = ref.read(searchFiltersProvider);
    final result = await ref.read(searchVideosUseCaseProvider)(
      trimmed,
      filters: filters,
    );
    state = result.when(
      ok: (page) {
        debugPrint('[search] ok: ${page.items.length} videos, '
            'hasMore=${page.hasMore}');
        return SearchLoaded(videos: page.items, hasMore: page.hasMore);
      },
      err: (f) {
        debugPrint('[search] err: $f');
        return SearchError(f.message);
      },
    );
  }

  Future<void> loadMore() async {
    final current = state;
    if (current is! SearchLoaded ||
        !current.hasMore ||
        current.loadingMore) {
      return;
    }
    state = current.copyWith(loadingMore: true);
    final result = await ref.read(loadMoreVideosUseCaseProvider)();
    state = result.when(
      ok: (page) {
        debugPrint('[search] loadMore ok: +${page.items.length}');
        return current.copyWith(
          videos: [...current.videos, ...page.items],
          hasMore: page.hasMore,
          loadingMore: false,
        );
      },
      err: (f) {
        debugPrint('[search] loadMore err: $f');
        return current.copyWith(loadingMore: false, hasMore: false);
      },
    );
  }

  void clear() {
    _lastQuery = '';
    state = const SearchInitial();
  }
}

final searchControllerProvider =
    NotifierProvider<SearchController, SearchState>(SearchController.new);
