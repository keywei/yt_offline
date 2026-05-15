import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../domain/entities/search_filters.dart';

/// Wraps `youtube_explode_dart`'s `VideoSearchList` and exposes a cursor-based
/// iteration. The cursor lives here so the repository stays simple.
class YoutubeSearchRemoteDataSource {
  final YoutubeExplode _yt;
  VideoSearchList? _cursor;

  YoutubeSearchRemoteDataSource(this._yt);

  Future<List<Video>> search(
    String query, {
    SearchFilters filters = SearchFilters.none,
  }) async {
    final sp = filters.toSpValue();
    final list = await _yt.search.search(
      query,
      filter: sp.isEmpty ? TypeFilters.video : SearchFilter(sp),
    );
    _cursor = list;
    return list.toList(growable: false);
  }

  /// Returns `null` if pagination is exhausted or [search] was never called.
  Future<List<Video>?> nextPage() async {
    final next = await _cursor?.nextPage();
    if (next == null) return null;
    _cursor = next;
    return next.toList(growable: false);
  }

  bool get hasCursor => _cursor != null;
}
