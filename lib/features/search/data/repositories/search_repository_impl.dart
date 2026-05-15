import 'dart:io';

import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/search_filters.dart';
import '../../domain/entities/video_page.dart';
import '../../domain/repositories/search_repository.dart';
import '../datasources/youtube_search_remote_datasource.dart';
import '../mappers/video_summary_mapper.dart';

class SearchRepositoryImpl implements SearchRepository {
  final YoutubeSearchRemoteDataSource _remote;
  bool _hasMore = false;

  SearchRepositoryImpl(this._remote);

  @override
  Future<Result<VideoPage>> search(
    String query, {
    SearchFilters filters = SearchFilters.none,
  }) async {
    try {
      final videos = await _remote.search(query, filters: filters);
      _hasMore = videos.isNotEmpty;
      return Ok(
        VideoPage(
          items: videos.map((v) => v.toSummary()).toList(growable: false),
          hasMore: _hasMore,
        ),
      );
    } on SocketException catch (e) {
      return Err(NetworkFailure(e.message));
    } catch (e) {
      return Err(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Result<VideoPage>> loadMore() async {
    if (!_remote.hasCursor) {
      return const Ok(VideoPage(items: [], hasMore: false));
    }
    try {
      final videos = await _remote.nextPage();
      if (videos == null || videos.isEmpty) {
        _hasMore = false;
        return const Ok(VideoPage(items: [], hasMore: false));
      }
      _hasMore = true;
      return Ok(
        VideoPage(
          items: videos.map((v) => v.toSummary()).toList(growable: false),
          hasMore: _hasMore,
        ),
      );
    } on SocketException catch (e) {
      return Err(NetworkFailure(e.message));
    } catch (e) {
      return Err(UnknownFailure(e.toString()));
    }
  }
}
