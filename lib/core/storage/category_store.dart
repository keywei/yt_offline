import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'media_storage.dart';

/// Persists the user-defined category list as `<documents>/categories.json`.
/// Empty categories (no videos yet) live here so they survive renames /
/// deletions of the videos that originally created them.
class CategoryStore {
  static const _filename = 'categories.json';
  final MediaStorage _storage;
  const CategoryStore(this._storage);

  Future<File> _file() async {
    final dir = await _storage.videosDir();
    // Sibling of the videos directory.
    return File(p.join(dir.parent.path, _filename));
  }

  Future<List<String>> list() async {
    final f = await _file();
    if (!await f.exists()) return [];
    try {
      final raw = await f.readAsString();
      return (jsonDecode(raw) as List<dynamic>).cast<String>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<String> all) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(all), flush: true);
  }

  Future<void> add(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final all = await list();
    if (all.any((c) => c.toLowerCase() == trimmed.toLowerCase())) return;
    all.add(trimmed);
    await _save(all);
  }

  Future<void> remove(String name) async {
    final all = await list();
    all.removeWhere((c) => c == name);
    await _save(all);
  }

  Future<void> rename(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final all = await list();
    final idx = all.indexOf(oldName);
    if (idx >= 0) all[idx] = trimmed;
    await _save(all);
  }
}
