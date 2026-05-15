import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persists recent search queries to `<documents>/search_history.json`.
/// Capped at 50 entries; most-recent first; case-insensitive dedup.
class SearchHistoryStore {
  static const _filename = 'search_history.json';
  static const _maxEntries = 50;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _filename));
  }

  Future<List<String>> load() async {
    final file = await _file();
    if (!await file.exists()) return [];
    try {
      final raw = await file.readAsString();
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<String>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<String> list) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(list), flush: true);
  }

  Future<void> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final current = await load();
    current.removeWhere((q) => q.toLowerCase() == trimmed.toLowerCase());
    current.insert(0, trimmed);
    if (current.length > _maxEntries) {
      current.removeRange(_maxEntries, current.length);
    }
    await _save(current);
  }

  Future<void> delete(String query) async {
    final current = await load();
    current.removeWhere((q) => q == query);
    await _save(current);
  }

  Future<void> clear() => _save([]);
}
