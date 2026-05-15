/// Infrastructure DTO describing a downloaded video on disk.
/// Stored as `<videoId>.json` next to the `.mp4` and optional `.srt`.
class VideoMetadata {
  static const String defaultCategory = 'Uncategorized';

  /// A video is considered "finished" (not resumable) once it crossed this
  /// fraction of its duration on the last play. Re-opening starts from
  /// the beginning instead of the saved position.
  static const double finishedThreshold = 0.95;

  final String id;
  final String title;
  final String author;
  final Duration duration;
  final String thumbnailUrl;
  final String videoPath;
  final String? subtitlePath;
  final DateTime downloadedAt;
  final String category;

  /// Sort order within its category (ascending). Default 0 keeps untouched
  /// items grouped at the top; they fall back to downloadedAt desc.
  final int position;

  /// Persisted playback position. null = never played (or just finished).
  final Duration? lastPosition;
  final DateTime? lastPositionAt;

  const VideoMetadata({
    required this.id,
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnailUrl,
    required this.videoPath,
    required this.subtitlePath,
    required this.downloadedAt,
    this.category = defaultCategory,
    this.position = 0,
    this.lastPosition,
    this.lastPositionAt,
  });

  /// Fraction (0..1) of the video already watched, based on [lastPosition].
  /// Returns 0 if there's no saved position or duration is unknown.
  double get watchedFraction {
    final lp = lastPosition;
    if (lp == null || duration <= Duration.zero) return 0;
    return (lp.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// True if [lastPosition] is set AND we shouldn't start from the beginning.
  bool get hasResumePoint {
    final lp = lastPosition;
    if (lp == null || lp <= const Duration(seconds: 3)) return false;
    return watchedFraction < finishedThreshold;
  }

  VideoMetadata copyWith({
    String? category,
    int? position,
    Object? lastPosition = _unchanged,
    Object? lastPositionAt = _unchanged,
  }) =>
      VideoMetadata(
        id: id,
        title: title,
        author: author,
        duration: duration,
        thumbnailUrl: thumbnailUrl,
        videoPath: videoPath,
        subtitlePath: subtitlePath,
        downloadedAt: downloadedAt,
        category: category ?? this.category,
        position: position ?? this.position,
        lastPosition: identical(lastPosition, _unchanged)
            ? this.lastPosition
            : lastPosition as Duration?,
        lastPositionAt: identical(lastPositionAt, _unchanged)
            ? this.lastPositionAt
            : lastPositionAt as DateTime?,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'durationSeconds': duration.inSeconds,
        'thumbnailUrl': thumbnailUrl,
        'videoPath': videoPath,
        'subtitlePath': subtitlePath,
        'downloadedAt': downloadedAt.toIso8601String(),
        'category': category,
        'position': position,
        'lastPositionSeconds': lastPosition?.inSeconds,
        'lastPositionAt': lastPositionAt?.toIso8601String(),
      };

  factory VideoMetadata.fromJson(Map<String, Object?> json) => VideoMetadata(
        id: json['id']! as String,
        title: json['title']! as String,
        author: json['author']! as String,
        duration: Duration(seconds: json['durationSeconds']! as int),
        thumbnailUrl: json['thumbnailUrl']! as String,
        videoPath: json['videoPath']! as String,
        subtitlePath: json['subtitlePath'] as String?,
        downloadedAt: DateTime.parse(json['downloadedAt']! as String),
        category: (json['category'] as String?) ?? defaultCategory,
        position: (json['position'] as int?) ?? 0,
        lastPosition: (json['lastPositionSeconds'] as int?) == null
            ? null
            : Duration(seconds: json['lastPositionSeconds']! as int),
        lastPositionAt: (json['lastPositionAt'] as String?) == null
            ? null
            : DateTime.parse(json['lastPositionAt']! as String),
      );
}

const Object _unchanged = Object();
