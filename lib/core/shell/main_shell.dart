import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/player/presentation/widgets/mini_player_bar.dart';
import '../../features/player/presentation/widgets/now_playing_shell.dart';
import '../i18n/strings.dart';

/// Hosts the bottom nav. Children are the per-tab navigators that
/// `StatefulShellRoute.indexedStack` builds for us. Wrapped by
/// [NowPlayingShell] so the expandable player overlay sits above the bottom
/// nav and keeps its Video widget mounted across mini↔full transitions.
class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const MainShell({required this.navigationShell, super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return NowPlayingShell(
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayerBar(),
            NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (i) => navigationShell.goBranch(
                i,
                initialLocation: i == navigationShell.currentIndex,
              ),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.search),
                  label: s.tabSearch,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.video_library_outlined),
                  selectedIcon: const Icon(Icons.video_library),
                  label: s.tabLibrary,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: s.tabSettings,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
