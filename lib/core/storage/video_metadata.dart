/// Infrastructure DTO describing a downloaded video on disk.
/// Stored as `<videoId>.json` next to the `.mp4` and optional `.srt`.
class VideoMetadata {
  static const String defaultCategory = 'Uncategorized';

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
  });

  VideoMetadata copyWith({String? category, int? position}) => VideoMetadata(
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
      );
}
