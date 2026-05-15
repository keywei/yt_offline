import 'package:flutter/material.dart';

import '../../domain/entities/video_summary.dart';

class VideoCard extends StatelessWidget {
  final VideoSummary video;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool? selected;

  const VideoCard({
    required this.video,
    this.onTap,
    this.onLongPress,
    this.selected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inSelectionMode = selected != null;
    return Material(
      color: (selected ?? false)
          ? theme.colorScheme.primaryContainer
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (inSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 6),
                  child: Icon(
                    (selected ?? false)
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: (selected ?? false)
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    size: 22,
                  ),
                ),
              SizedBox(
                width: 160,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: Colors.black12),
                        Image.network(
                          video.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              const SizedBox.shrink(),
                        ),
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: _DurationBadge(duration: video.duration),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      video.author,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatViews(video.viewCount),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatViews(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M views';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K views';
    return '$n views';
  }
}

class _DurationBadge extends StatelessWidget {
  final Duration duration;
  const _DurationBadge({required this.duration});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        _format(duration),
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0
        ? '$h:${m.toString().padLeft(2, '0')}:$s'
        : '$m:$s';
  }
}
