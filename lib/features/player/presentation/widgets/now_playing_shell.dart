import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/playback_providers.dart';
import '../state/now_playing_provider.dart';
import 'full_player.dart';

/// Hosts the persistent "now playing" surface above [child]. The Video widget
/// inside [FullPlayer] is kept mounted across the mini↔full transition so
/// libmpv's iOS render pipeline never has to re-attach a Texture (which is
/// what stalls it).
///
/// Three layout modes share the same [FullPlayer]:
///   - **collapsed portrait** — overlay slid off screen, mini bar visible
///   - **expanded portrait** — slid up to fill the screen, drag-to-collapse
///   - **landscape**         — covers everything including bottom nav, system
///                             UI is hidden (YouTube-style fullscreen)
class NowPlayingShell extends ConsumerStatefulWidget {
  final Widget child;
  const NowPlayingShell({required this.child, super.key});

  @override
  ConsumerState<NowPlayingShell> createState() => _NowPlayingShellState();
}

class _NowPlayingShellState extends ConsumerState<NowPlayingShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _wasLandscape = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _applySystemUi({
    required bool expanded,
    required bool landscape,
  }) {
    if (landscape) {
      // YouTube-style fullscreen: hide both status bar and nav buttons.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(
        expanded ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(nowPlayingExpandedProvider, (prev, next) {
      if (next) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    });

    final expanded = ref.watch(nowPlayingExpandedProvider);
    final hasCurrent = ref.watch(
      playbackControllerProvider.select((s) => s.current != null),
    );
    final orientation = MediaQuery.orientationOf(context);
    final isLandscape = orientation == Orientation.landscape && hasCurrent;

    // Re-apply system UI whenever the relevant axes change.
    if (isLandscape != _wasLandscape ||
        _ctrl.status == AnimationStatus.forward) {
      _wasLandscape = isLandscape;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applySystemUi(expanded: expanded, landscape: isLandscape);
      });
    }

    // Landscape: video takes the full screen, the rest of the app is hidden.
    if (isLandscape) {
      return PopScope(
        // Let the system back gesture / button behave as usual (Android
        // typically rotates back when the user does this from landscape).
        canPop: !expanded,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && expanded) {
            ref.read(nowPlayingExpandedProvider.notifier).state = false;
          }
        },
        child: FullPlayer(
          landscape: true,
          onCollapse: () =>
              ref.read(nowPlayingExpandedProvider.notifier).state = false,
        ),
      );
    }

    // Portrait: child + sliding overlay (the existing behaviour).
    final screenHeight = MediaQuery.of(context).size.height;
    return PopScope(
      canPop: !expanded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && expanded) {
          ref.read(nowPlayingExpandedProvider.notifier).state = false;
        }
      },
      child: Stack(
        children: [
          widget.child,
          if (hasCurrent)
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) {
                final top = screenHeight * (1.0 - _ctrl.value);
                return Positioned(
                  left: 0,
                  right: 0,
                  top: top,
                  height: screenHeight,
                  child: IgnorePointer(
                    ignoring: _ctrl.value < 0.5,
                    child: child!,
                  ),
                );
              },
              child: FullPlayer(
                landscape: false,
                onCollapse: () => ref
                    .read(nowPlayingExpandedProvider.notifier)
                    .state = false,
              ),
            ),
        ],
      ),
    );
  }
}
