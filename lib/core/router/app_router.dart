import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/library/presentation/screens/library_screen.dart';
import '../../features/player/presentation/screens/player_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../shell/main_shell.dart';

abstract final class Routes {
  static const search = '/search';
  static const library = '/library';
  static const player = '/player';
}

final _rootKey = GlobalKey<NavigatorState>();
final _searchKey = GlobalKey<NavigatorState>();
final _libraryKey = GlobalKey<NavigatorState>();

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
        ],
      ),
      GoRoute(
        path: Routes.player,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const PlayerScreen(),
      ),
    ],
  ),
);
