import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/library/presentation/screens/library_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/storage_screen.dart';
import '../../features/settings/presentation/screens/subtitle_settings_screen.dart';
import '../shell/main_shell.dart';

abstract final class Routes {
  static const search = '/search';
  static const library = '/library';
  static const settings = '/settings';
  static const subtitleSettings = 'subtitles';
  static const storage = 'storage';
  static const history = 'history';
}

final _rootKey = GlobalKey<NavigatorState>();
final _searchKey = GlobalKey<NavigatorState>();
final _libraryKey = GlobalKey<NavigatorState>();
final _settingsKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.search,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _searchKey,
            routes: [
              GoRoute(
                path: Routes.search,
                builder: (_, _) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _libraryKey,
            routes: [
              GoRoute(
                path: Routes.library,
                builder: (_, _) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _settingsKey,
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (_, _) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: Routes.subtitleSettings,
                    builder: (_, _) => const SubtitleSettingsScreen(),
                  ),
                  GoRoute(
                    path: Routes.storage,
                    builder: (_, _) => const StorageScreen(),
                  ),
                  GoRoute(
                    path: Routes.history,
                    builder: (_, _) => const HistoryScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  ),
);
