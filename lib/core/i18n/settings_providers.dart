import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/preferences_store.dart';

final preferencesStoreProvider =
    Provider<PreferencesStore>((_) => PreferencesStore());

/// Loaded asynchronously from disk on app start. Mutations go through
/// `setLocale` / `setThemeMode` and persist on every change so a kill /
/// reopen keeps the user's choice.
class AppPreferencesNotifier extends AsyncNotifier<AppPreferences> {
  @override
  Future<AppPreferences> build() =>
      ref.read(preferencesStoreProvider).load();

  Future<void> setLocale(Locale locale) async {
    final current = state.valueOrNull ?? AppPreferences.defaults;
    final updated = current.copyWith(locale: locale);
    state = AsyncData(updated);
    await ref.read(preferencesStoreProvider).save(updated);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final current = state.valueOrNull ?? AppPreferences.defaults;
    final updated = current.copyWith(themeMode: mode);
    state = AsyncData(updated);
    await ref.read(preferencesStoreProvider).save(updated);
  }

  Future<void> setSubtitleStyle({
    double? fontSize,
    int? colorArgb,
    double? backgroundAlpha,
    int? position,
  }) async {
    final current = state.valueOrNull ?? AppPreferences.defaults;
    final updated = current.copyWith(
      subtitleFontSize: fontSize,
      subtitleColorArgb: colorArgb,
      subtitleBackgroundAlpha: backgroundAlpha,
      subtitlePosition: position,
    );
    state = AsyncData(updated);
    await ref.read(preferencesStoreProvider).save(updated);
  }
}

final appPreferencesProvider =
    AsyncNotifierProvider<AppPreferencesNotifier, AppPreferences>(
  AppPreferencesNotifier.new,
);
