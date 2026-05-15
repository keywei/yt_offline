import 'package:flutter/material.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../data/datasources/youtube_search_remote_datasource.dart';
import '../../data/repositories/search_repository_impl.dart';
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

class SearchController extends Notifier<SearchState> {
  @override
  SearchState build() => const SearchInitial();

  Future<void> search(String query) async {
    debugPrint('[search] start: "$query"');
    state = const SearchLoading();
    final result = await ref.read(searchVideosUseCaseProvider)(query);
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

  void clear() => state = const SearchInitial();
}

final searchControllerProvider =
    NotifierProvider<SearchController, SearchState>(SearchController.new);
