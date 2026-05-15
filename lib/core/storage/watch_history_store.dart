import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// One row in the watch history log. Created when [PlaybackController]
/// starts a video and updated as the user scrubs / closes / completes.
class WatchEvent {
  final String videoId;
  final String title;
  final DateTime startedAt;
  final DateTime? endedAt;

  /// Last known playback position when this row was last touched.
  final Duration lastPosition;

  /// Frozen video duration so the History UI can render % bars without
  /// re-reading the video metadata (which may have been deleted).
  final Duration duration;

  const WatchEvent({
    required this.videoId,
    required this.title,
    required this.startedAt,
    required this.endedAt,
    required this.lastPosition,
    required this.duration,
  });

  WatchEvent copyWith({
    DateTime? endedAt,
    Duration? lastPosition,
  }) =>
      WatchEvent(
        videoId: videoId,
        title: title,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
        lastPosition: lastPosition ?? this.lastPosition,
        duration: duration,
      );

  Map<String, Object?> toJson() => {
        'videoId': videoId,
        'title': title,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'lastPositionSeconds': lastPosition.inSeconds,
        'durationSeconds': duration.inSeconds,
      };

  factory WatchEvent.fromJson(Map<String, Object?> json) => WatchEvent(
        videoId: json['videoId']! as String,
        title: (json['title'] as String?) ?? '',
        startedAt: DateTime.parse(json['startedAt']! as String),
        endedAt: (json['endedAt'] as String?) == null
            ? null
            : DateTime.parse(json['endedAt']! as String),
        lastPosition:
            Duration(seconds: (json['lastPositionSeconds'] as int?) ?? 0),
        duration: Duration(seconds: (json['durationSeconds'] as int?) ?? 0),
      );
}

/// JSON-backed history log at `<documents>/watch_history.json`. Matches
/// the on-disk pattern already used by the other stores in this project
/// (search_history, categories, preferences).
class WatchHistoryStore {
  static const _filename = 'watch_history.json';
  static const _maxEntries = 500;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _filename));
  }

  Future<List<WatchEvent>> load() async {
    final f = await _file();
    // Important: return a *mutable* list. `recordStart` calls `.add()` on
    // the result; const [] would throw UnsupportedError and be swallowed
    // by the best-effort catch around it, silently dropping every entry
    // until the file existed for an unrelated reason.
    if (!await f.exists()) return <WatchEvent>[];
    try {
      final raw = await f.readAsString();
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => WatchEvent.fromJson(e as Map<String, Object?>))
          .toList();
    } catch (_) {
      return <WatchEvent>[];
    }
  }

  Future<void> _save(List<WatchEvent> events) async {
    final f = await _file();
    final trimmed = events.length > _maxEntries
        ? events.sublist(events.length - _maxEntries)
        : events;
    await f.writeAsString(
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
      flush: true,
    );
  }

  /// Append a fresh "started watching" row.
  Future<void> recordStart(WatchEvent event) async {
    final all = await load();
    all.add(event);
    await _save(all);
  }

  /// Update the most recent unfinished row for [videoId]. Falls back to a
  /// fresh record if none is found.
  Future<void> updateLatest(
    String videoId, {
    Duration? lastPosition,
    DateTime? endedAt,
  }) async {
    final all = await load();
    final idx = all.lastIndexWhere((e) => e.videoId == videoId);
    if (idx < 0) return;
    all[idx] = all[idx].copyWith(
      lastPosition: lastPosition,
      endedAt: endedAt,
    );
    await _save(all);
  }

  Future<void> clear() async {
    final f = await _file();
    if (await f.exists()) {
      await f.delete();
    }
  }
}
