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

  /// libmpv `sub-font-size`. Default 55. Sensible range ~20–120.
  final double subtitleFontSize;

  /// Foreground color as ARGB. Default opaque white.
  final int subtitleColorArgb;

  /// Background opacity for the subtitle box [0.0..1.0]. 0 = transparent.
  /// Maps to libmpv `sub-back-color` alpha channel; the colour is black.
  final double subtitleBackgroundAlpha;

  /// libmpv `sub-pos` [0..150]. 100 = bottom, 0 = top.
  final int subtitlePosition;

  const AppPreferences({
    required this.locale,
    required this.themeMode,
    required this.subtitleFontSize,
    required this.subtitleColorArgb,
    required this.subtitleBackgroundAlpha,
    required this.subtitlePosition,
  });

  static const _defaultLocale = Locale('en');
  static const defaults = AppPreferences(
    locale: _defaultLocale,
    themeMode: ThemeMode.system,
    subtitleFontSize: 55,
    subtitleColorArgb: 0xFFFFFFFF,
    subtitleBackgroundAlpha: 0.5,
    subtitlePosition: 100,
  );

  AppPreferences copyWith({
    Locale? locale,
    ThemeMode? themeMode,
    double? subtitleFontSize,
    int? subtitleColorArgb,
    double? subtitleBackgroundAlpha,
    int? subtitlePosition,
  }) =>
      AppPreferences(
        locale: locale ?? this.locale,
        themeMode: themeMode ?? this.themeMode,
        subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
        subtitleColorArgb: subtitleColorArgb ?? this.subtitleColorArgb,
        subtitleBackgroundAlpha:
            subtitleBackgroundAlpha ?? this.subtitleBackgroundAlpha,
        subtitlePosition: subtitlePosition ?? this.subtitlePosition,
      );

  Map<String, Object?> toJson() => {
        'localeLanguage': locale.languageCode,
        'localeCountry': locale.countryCode,
        'themeMode': themeMode.name,
        'subtitleFontSize': subtitleFontSize,
        'subtitleColorArgb': subtitleColorArgb,
        'subtitleBackgroundAlpha': subtitleBackgroundAlpha,
        'subtitlePosition': subtitlePosition,
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
      subtitleFontSize:
          (json['subtitleFontSize'] as num?)?.toDouble() ?? 55.0,
      subtitleColorArgb:
          (json['subtitleColorArgb'] as int?) ?? 0xFFFFFFFF,
      subtitleBackgroundAlpha:
          (json['subtitleBackgroundAlpha'] as num?)?.toDouble() ?? 0.5,
      subtitlePosition: (json['subtitlePosition'] as int?) ?? 100,
    );
  }

  /// Converts [subtitleColorArgb] to libmpv's `#RRGGBB` form (opaque).
  String get subtitleColorHex {
    final r = ((subtitleColorArgb >> 16) & 0xFF).toRadixString(16).padLeft(2, '0');
    final g = ((subtitleColorArgb >> 8) & 0xFF).toRadixString(16).padLeft(2, '0');
    final b = (subtitleColorArgb & 0xFF).toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  /// `#AARRGGBB` black with the configured alpha — for libmpv
  /// `sub-back-color`. mpv expects ARGB order.
  String get subtitleBackgroundHex {
    final a = (subtitleBackgroundAlpha * 255)
        .clamp(0, 255)
        .toInt()
        .toRadixString(16)
        .padLeft(2, '0');
    return '#${a}000000';
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
