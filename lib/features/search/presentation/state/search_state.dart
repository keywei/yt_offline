import 'package:flutter/foundation.dart';

import '../../domain/entities/video_summary.dart';

@immutable
sealed class SearchState {
  const SearchState();
}

class SearchInitial extends SearchState {
  const SearchInitial();
}

class SearchLoading extends SearchState {
  const SearchLoading();
}

class SearchLoaded extends SearchState {
  final List<VideoSummary> videos;
  final bool hasMore;
  final bool loadingMore;

  const SearchLoaded({
    required this.videos,
    required this.hasMore,
    this.loadingMore = false,
  });

  SearchLoaded copyWith({
    List<VideoSummary>? videos,
    bool? hasMore,
    bool? loadingMore,
  }) =>
      SearchLoaded(
        videos: videos ?? this.videos,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

class SearchError extends SearchState {
  final String message;
  const SearchError(this.message);
}
