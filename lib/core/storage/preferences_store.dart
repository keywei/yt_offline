import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persisted app-level preferences. Lives at `<documents>/preferences.json`
/// — same on-disk-as-JSON pattern as the other stores in this project, so
/// we don't bring in another plugin just for two settings.
class AppPreferences {
  final Locale locale;
  final ThemeMode themeMode;

  const AppPreferences({
    required this.locale,
    required this.themeMode,
  });

  static const _defaultLocale = Locale('en');
  static const defaults = AppPreferences(
    locale: _defaultLocale,
    themeMode: ThemeMode.system,
  );

  AppPreferences copyWith({Locale? locale, ThemeMode? themeMode}) =>
      AppPreferences(
        locale: locale ?? this.locale,
        themeMode: themeMode ?? this.themeMode,
      );

  Map<String, Object?> toJson() => {
        'localeLanguage': locale.languageCode,
        'localeCountry': locale.countryCode,
        'themeMode': themeMode.name,
      };

  factory AppPreferences.fromJson(Map<String, Object?> json) {
    final lang = json['localeLanguage'] as String? ?? 'en';
    final country = json['localeCountry'] as String?;
    final modeName = json['themeMode'] as String? ?? 'system';
    return AppPreferences(
      locale: country == null ? Locale(lang) : Locale(lang, country),
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == modeName,
        orElse: () => ThemeMode.system,
      ),
    );
  }
}

class PreferencesStore {
  static const _filename = 'preferences.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _filename));
  }

  Future<AppPreferences> load() async {
    final f = await _file();
    if (!await f.exists()) return AppPreferences.defaults;
    try {
      final raw = await f.readAsString();
      return AppPreferences.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } catch (_) {
      return AppPreferences.defaults;
    }
  }

  Future<void> save(AppPreferences prefs) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(prefs.toJson()), flush: true);
  }
}
