import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/player/presentation/widgets/mini_player_bar.dart';
import '../../features/player/presentation/widgets/now_playing_shell.dart';

/// Hosts the bottom nav. Children are the per-tab navigators that
/// `StatefulShellRoute.indexedStack` builds for us. Wrapped by
/// [NowPlayingShell] so the expandable player overlay sits above the bottom
/// nav and keeps its Video widget mounted across mini↔full transitions.
class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const MainShell({required this.navigationShell, super.key});

  @override
  Widget build(BuildContext context) {
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
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.search),
                  label: 'Search',
                ),
                NavigationDestination(
                  icon: Icon(Icons.video_library_outlined),
                  selectedIcon: Icon(Icons.video_library),
                  label: 'Library',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
