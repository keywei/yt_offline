import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Resolves a videoId into a downloadable mp4 URL and (optionally) SRT
/// subtitle text. We only pick from `muxed` streams to avoid having to
/// run ffmpeg on-device to combine separate audio/video tracks; this caps
/// quality at ~720p but keeps the pipeline simple.
class YoutubeStreamDataSource {
  final YoutubeExplode _yt;
  const YoutubeStreamDataSource(this._yt);

  Future<ResolvedStream> resolve(String videoId) async {
    final video = await _yt.videos.get(videoId);

    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    if (manifest.muxed.isEmpty) {
      throw const FormatException('No muxed stream available for this video.');
    }
    final stream = manifest.muxed.withHighestBitrate();

    String? srt;
    try {
      final captionManifest =
          await _yt.videos.closedCaptions.getManifest(videoId);
      final track = _pickTrack(captionManifest.tracks);
      if (track != null) {
        final cc = await _yt.videos.closedCaptions.get(track);
        srt = _formatAsSrt(cc.captions);
      }
    } catch (_) {
      // No captions — that's fine.
    }

    return ResolvedStream(
      streamUrl: stream.url.toString(),
      subtitleSrt: srt,
      title: video.title,
      author: video.author,
      duration: video.duration ?? Duration.zero,
      thumbnailUrl: video.thumbnails.mediumResUrl,
    );
  }

  ClosedCaptionTrackInfo? _pickTrack(List<ClosedCaptionTrackInfo> tracks) {
    if (tracks.isEmpty) return null;
    for (final t in tracks) {
      if (t.language.code.startsWith('en')) return t;
    }
    return tracks.first;
  }

  String _formatAsSrt(List<ClosedCaption> captions) {
    final buf = StringBuffer();
    for (var i = 0; i < captions.length; i++) {
      final c = captions[i];
      buf.writeln(i + 1);
      buf.writeln('${_srtTime(c.offset)} --> ${_srtTime(c.offset + c.duration)}');
      buf.writeln(c.text);
      buf.writeln();
    }
    return buf.toString();
  }

  String _srtTime(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final ms = d.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
    return '$h:$m:$s,$ms';
  }
}

class ResolvedStream {
  final String streamUrl;
  final String? subtitleSrt;
  final String title;
  final String author;
  final Duration duration;
  final String thumbnailUrl;

  const ResolvedStream({
    required this.streamUrl,
    required this.subtitleSrt,
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnailUrl,
  });
}
