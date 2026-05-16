import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';

import '../../../../core/i18n/strings.dart';

/// Controls the **system** media volume — same channel
/// `flutter_volume_controller` drives from the landscape vertical-swipe
/// gesture. Stays in sync with hardware volume buttons via a listener
/// for as long as the sheet is mounted.
class VolumeSheet extends StatefulWidget {
  const VolumeSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const VolumeSheet(),
    );
  }

  @override
  State<VolumeSheet> createState() => _VolumeSheetState();
}

class _VolumeSheetState extends State<VolumeSheet> {
  /// 0..1; `null` until the first read resolves.
  double? _value;

  /// True while the user is mid-drag — we ignore listener pushes during
  /// that window so the thumb doesn't jitter against our writes.
  bool _draggingLocal = false;

  /// Snapshot of the pre-mute volume so the toggle can restore it.
  double? _preMute;

  StreamSubscription<double>? _listener;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final v = await FlutterVolumeController.getVolume();
      if (!mounted) return;
      setState(() => _value = v ?? 0);
      _listener = FlutterVolumeController.addListener((nv) {
        if (!mounted || _draggingLocal) return;
        setState(() => _value = nv);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _value = 0);
    }
  }

  @override
  void dispose() {
    _listener?.cancel();
    super.dispose();
  }

  Future<void> _set(double v) async {
    final clamped = v.clamp(0.0, 1.0);
    setState(() => _value = clamped);
    try {
      await FlutterVolumeController.setVolume(clamped);
    } catch (_) {
      // Platform side may refuse (eg. silent mode); next listener push
      // will reconcile.
    }
  }

  Future<void> _toggleMute() async {
    final v = _value;
    if (v == null) return;
    if (v <= 0.001) {
      await _set(_preMute ?? 0.5);
    } else {
      _preMute = v;
      await _set(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final value = _value;
    final pct = value == null ? '—' : '${(value * 100).round()}%';
    final muted = value != null && value <= 0.001;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              s.volumeTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  tooltip: muted ? s.volumeUnmute : s.volumeMute,
                  icon: Icon(
                    muted
                        ? Icons.volume_off
                        : (value != null && value < 0.5
                            ? Icons.volume_down
                            : Icons.volume_up),
                  ),
                  onPressed: value == null ? null : _toggleMute,
                ),
                Expanded(
                  child: Slider(
                    value: value ?? 0,
                    onChangeStart: (_) => _draggingLocal = true,
                    onChanged: value == null ? null : _set,
                    onChangeEnd: (_) => _draggingLocal = false,
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(pct, textAlign: TextAlign.right),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
