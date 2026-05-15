import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Owns the on-disk layout: `<documents>/videos/<id>.{mp4,srt,json}`.
class MediaStorage {
  Directory? _cached;

  Future<Directory> videosDir() async {
    if (_cached != null) return _cached!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'videos'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _cached = dir;
    return dir;
  }

  /// Sub-path relative to `applicationDocuments` — what
  /// `background_downloader` wants when using `BaseDirectory.applicationDocuments`.
  String get videosSubDir => 'videos';

  Future<File> videoFile(String id) async =>
      File(p.join((await videosDir()).path, '$id.mp4'));

  Future<File> subtitleFile(String id) async =>
      File(p.join((await videosDir()).path, '$id.srt'));

  Future<File> metadataFile(String id) async =>
      File(p.join((await videosDir()).path, '$id.json'));
}
