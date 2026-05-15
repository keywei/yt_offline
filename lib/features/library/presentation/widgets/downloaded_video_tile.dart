import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/storage/video_metadata.dart';
import 'equalizer_indicator.dart';

class DownloadedVideoTile extends StatelessWidget {
  final VideoMetadata meta;
  /// Currently the active item in the playback queue.
  final bool isCurrent;
  /// And actively playing (not paused). Animates the equalizer.
  final bool isPlayingNow;
  /// `null` = not in selection mode (default UI).
  /// `true`/`false` = selection mode is on; show a checkbox.
  final bool? selected;
  final VoidCallback? onTap;

  const DownloadedVideoTile({
    required this.meta,
    this.isCurrent = false,
    this.isPlayingNow = false,
    this.selected,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileExists = File(meta.videoPath).existsSync();
    final inSelection = selected != null;

    return Material(
      color: (selected ?? false)
          ? theme.colorScheme.primaryContainer
          : isCurrent
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
      child: ListTile(
        onTap: onTap,
        leading: ClipRRect(
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
        ),
        title: Text(
          meta.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: isCurrent ? FontWeight.bold : null,
            color: isCurrent ? theme.colorScheme.onPrimaryContainer : null,
          ),
        ),
        subtitle: Text(
          '${meta.author} • ${_fmtDuration(meta.duration)}'
          '${meta.subtitlePath != null ? ' • CC' : ''}'
          '${fileExists ? '' : ' • missing file'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
