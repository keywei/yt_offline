import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/strings.dart';
import '../providers/playback_providers.dart';
import '../state/now_playing_provider.dart';

/// Persistent strip shown above the bottom nav while playback is active.
/// Tap → expand the NowPlayingShell overlay (no route push). Collapses to
/// nothing when idle.
class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackControllerProvider);
    final current = state.current;
    if (current == null) return const SizedBox.shrink();

    final controller = ref.read(playbackControllerProvider.notifier);
    final theme = Theme.of(context);

    final progress = state.duration.inMilliseconds > 0
        ? state.position.inMilliseconds / state.duration.inMilliseconds
        : 0.0;

    // Body and controls live in SEPARATE InkWell/IconButton subtrees so the
    // hit test never has to pick between them. Earlier the whole row sat
    // inside one InkWell and a stray tap near the right edge of the title
    // could be eaten by the IconButton's 48x48 hit area, pausing the video.
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 2,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
          SizedBox(
            height: 56,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => ref
                        .read(nowPlayingExpandedProvider.notifier)
                        .state = true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              width: 56,
                              height: 40,
                              child: Image.network(
                                current.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const ColoredBox(color: Colors.black12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  current.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium,
                                ),
                                Text(
                                  '${current.author} • ${S.of(context).displayCategory(current.category)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    state.isPlaying ? Icons.pause : Icons.play_arrow,
                  ),
                  onPressed: controller.togglePlayPause,
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: controller.next,
                ),
                IconButton(
                  tooltip: S.of(context).stop,
                  icon: const Icon(Icons.close),
                  onPressed: controller.stop,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
