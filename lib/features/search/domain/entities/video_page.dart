import 'package:flutter/foundation.dart';

import 'video_summary.dart';

@immutable
class VideoPage {
  final List<VideoSummary> items;
  final bool hasMore;

  const VideoPage({required this.items, required this.hasMore});
}
