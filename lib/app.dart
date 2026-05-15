import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/i18n/settings_providers.dart';
import 'core/i18n/strings.dart';
import 'core/router/app_router.dart';
import 'core/storage/preferences_store.dart';
import 'features/download/presentation/providers/download_providers.dart';

class YtOfflineApp extends ConsumerWidget {
  const YtOfflineApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final init = ref.watch(downloadInitializerProvider);
    final prefs = ref.watch(appPreferencesProvider).valueOrNull ??
        AppPreferences.defaults;
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      useMaterial3: true,
    );
    final darkTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );

    const localizationsDelegates = <LocalizationsDelegate<Object>>[
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ];

    return init.when(
      data: (_) {
        final router = ref.watch(appRouterProvider);
        return MaterialApp.router(
          title: 'YT Offline',
          theme: theme,
          darkTheme: darkTheme,
          themeMode: prefs.themeMode,
          locale: prefs.locale,
          supportedLocales: supportedLocales,
          localizationsDelegates: localizationsDelegates,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        );
      },
      loading: () => MaterialApp(
        theme: theme,
        darkTheme: darkTheme,
        themeMode: prefs.themeMode,
        locale: prefs.locale,
        supportedLocales: supportedLocales,
        localizationsDelegates: localizationsDelegates,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        debugShowCheckedModeBanner: false,
      ),
      error: (e, _) => MaterialApp(
        theme: theme,
        darkTheme: darkTheme,
        themeMode: prefs.themeMode,
        locale: prefs.locale,
        supportedLocales: supportedLocales,
        localizationsDelegates: localizationsDelegates,
        home: Scaffold(
          body: Center(child: Text('Startup failed: $e')),
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
