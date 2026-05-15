import 'package:flutter/foundation.dart';

import 'download_status.dart';

@immutable
class DownloadJob {
  /// Either a `prep:<videoId>:<ts>` synthetic key (phase A) or the
  /// background_downloader taskId (phase B onward).
  final String id;
  final String videoId;
  final String title;
  final String thumbnailUrl;
  final String category;
  final DownloadStatus status;
  final double progress;
  final String? error;

  const DownloadJob({
    required this.id,
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
    required this.category,
    required this.status,
    this.progress = 0.0,
    this.error,
  });

  DownloadJob copyWith({
    String? id,
    DownloadStatus? status,
    double? progress,
    String? error,
  }) =>
      DownloadJob(
        id: id ?? this.id,
        videoId: videoId,
        title: title,
        thumbnailUrl: thumbnailUrl,
        category: category,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        error: error ?? this.error,
      );
}
