import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/storage/video_metadata.dart';
import 'equalizer_indicator.dart';

class DownloadedVideoTile extends StatelessWidget {
  final VideoMetadata meta;
  /// Currently selected by the playback controller (this is THE active item).
  final bool isCurrent;
  /// And actually playing right now (not paused). Drives the equalizer
  /// animation; ignored when [isCurrent] is false.
  final bool isPlayingNow;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const DownloadedVideoTile({
    required this.meta,
    this.isCurrent = false,
    this.isPlayingNow = false,
    this.onTap,
    this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileExists = File(meta.videoPath).existsSync();
    return Material(
      color: isCurrent
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
        trailing: onDelete == null
            ? null
            : IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
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
