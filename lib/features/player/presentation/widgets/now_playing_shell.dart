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
/// Expansion is driven by [nowPlayingExpandedProvider]: tapping the mini
/// player body flips it true; the collapse arrow and Android back flip it
/// back to false.
class NowPlayingShell extends ConsumerStatefulWidget {
  final Widget child;
  const NowPlayingShell({required this.child, super.key});

  @override
  ConsumerState<NowPlayingShell> createState() => _NowPlayingShellState();
}

class _NowPlayingShellState extends ConsumerState<NowPlayingShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

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

  void _applySystemUi(bool expanded) {
    SystemChrome.setSystemUIOverlayStyle(
      expanded
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Drive the animation off the Riverpod flag so mini taps / back gestures /
    // route-level openings (library auto-expand on first play) all flow
    // through the same source of truth.
    ref.listen<bool>(nowPlayingExpandedProvider, (prev, next) {
      if (next) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
      _applySystemUi(next);
    });

    final expanded = ref.watch(nowPlayingExpandedProvider);
    final hasCurrent = ref.watch(
      playbackControllerProvider.select((s) => s.current != null),
    );
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
          // Always mount FullPlayer while there is a current video so the
          // Video widget never unmounts. Positioned off-screen when
          // collapsed; slides up to fill the screen when expanded.
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
                    // While the overlay is mostly off-screen, let taps fall
                    // through to the mini bar / nav bar underneath.
                    ignoring: _ctrl.value < 0.5,
                    child: child!,
                  ),
                );
              },
              child: FullPlayer(
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
