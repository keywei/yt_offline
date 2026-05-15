import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/storage/video_metadata.dart';
import 'equalizer_indicator.dart';

/// A library row split into two gesture regions that fill the row's width:
///   - LEFT region (thumbnail + padding around it): long-press → batch select
///   - RIGHT region (title/subtitle + trailing padding): wrapped by
///     [bodyWrapper] so the caller can attach `LongPressDraggable` for drag
///
/// Tapping either region triggers [onTap] (play / toggle).
class DownloadedVideoTile extends StatelessWidget {
  final VideoMetadata meta;
  final bool isCurrent;
  final bool isPlayingNow;
  final bool? selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPressThumbnail;
  final Widget Function(Widget child)? bodyWrapper;

  const DownloadedVideoTile({
    required this.meta,
    this.isCurrent = false,
    this.isPlayingNow = false,
    this.selected,
    this.onTap,
    this.onLongPressThumbnail,
    this.bodyWrapper,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileExists = File(meta.videoPath).existsSync();
    final inSelection = selected != null;

    final watched = meta.watchedFraction;
    final thumbnail = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 96,
        height: 56,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              meta.thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: Colors.black12),
            ),
            // YouTube-style "watched so far" bar across the bottom of the
            // thumbnail. Only drawn for partially-watched items.
            if (meta.hasResumePoint)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 3,
                  color: Colors.black45,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: watched,
                    child: Container(color: theme.colorScheme.primary),
                  ),
                ),
              ),
            if (isCurrent)
              Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: EqualizerIndicator(
                  playing: isPlayingNow,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            if (inSelection)
              Container(
                color: Colors.black38,
                alignment: Alignment.center,
                child: Icon(
                  (selected ?? false)
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: Colors.white,
                  size: 28,
                ),
              ),
          ],
        ),
      ),
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          meta.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: isCurrent ? FontWeight.bold : null,
            color: isCurrent ? theme.colorScheme.onPrimaryContainer : null,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${meta.author} • ${_fmtDuration(meta.duration)}'
          '${meta.subtitlePath != null ? ' • CC' : ''}'
          '${meta.hasResumePoint ? ' • Resume ${_fmtDuration(meta.lastPosition!)}' : ''}'
          '${fileExists ? '' : ' • missing file'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );

    // Each region gets `opaque` so it captures the gesture and stops the
    // visual tree from defaulting to the parent (no ripple flicker), but
    // tap still ends up calling onTap directly here so it works on either
    // side. Padding lives INSIDE each region so the "background" around
    // each visual is also part of that region's hit target.
    final leftRegion = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPressThumbnail,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: thumbnail,
      ),
    );

    final rightRegionContent = Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 12, 8),
      child: body,
    );

    final rightRegion = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: bodyWrapper == null
          ? rightRegionContent
          : bodyWrapper!(rightRegionContent),
    );

    return Material(
      color: (selected ?? false) || isCurrent
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          leftRegion,
          Expanded(child: rightRegion),
        ],
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0
        ? '$h:${m.toString().padLeft(2, '0')}:$s'
        : '$m:$s';
  }
}
