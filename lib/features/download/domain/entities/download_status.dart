enum DownloadStatus {
  /// Resolving the stream URL + captions via youtube_explode_dart (phase A).
  /// No background_downloader task yet.
  preparing,
  queued,
  running,
  paused,
  complete,
  failed,
  canceled;

  bool get isTerminal =>
      this == complete || this == failed || this == canceled;

  bool get isActive =>
      this == preparing || this == queued || this == running;
}
