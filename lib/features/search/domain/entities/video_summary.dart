import 'package:flutter/foundation.dart';

@immutable
class VideoSummary {
  final String id;
  final String title;
  final String author;
  final String thumbnailUrl;
  final Duration duration;
  final int viewCount;

  const VideoSummary({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.duration,
    required this.viewCount,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoSummary &&
          other.id == id &&
          other.title == title &&
          other.author == author &&
          other.thumbnailUrl == thumbnailUrl &&
          other.duration == duration &&
          other.viewCount == viewCount;

  @override
  int get hashCode =>
      Object.hash(id, title, author, thumbnailUrl, duration, viewCount);
}
