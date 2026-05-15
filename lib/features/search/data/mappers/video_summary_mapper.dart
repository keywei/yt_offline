import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../domain/entities/video_summary.dart';

/// Maps the third-party `Video` type into our domain entity.
/// Lives in the data layer so domain stays library-free.
extension VideoToSummary on Video {
  VideoSummary toSummary() => VideoSummary(
        id: id.value,
        title: title,
        author: author,
        thumbnailUrl: thumbnails.mediumResUrl,
        duration: duration ?? Duration.zero,
        viewCount: engagement.viewCount,
      );
}
