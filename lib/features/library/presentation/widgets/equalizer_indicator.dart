import 'dart:math';

import 'package:flutter/material.dart';

/// 3 vertical bars that bounce when [playing] is true; static when paused.
class EqualizerIndicator extends StatefulWidget {
  final bool playing;
  final Color color;
  final double size;

  const EqualizerIndicator({
    required this.playing,
    this.color = Colors.white,
    this.size = 18,
    super.key,
  });

  @override
  State<EqualizerIndicator> createState() => _EqualizerIndicatorState();
}

class _EqualizerIndicatorState extends State<EqualizerIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant EqualizerIndicator old) {
    super.didUpdateWidget(old);
    if (widget.playing != old.playing) {
      if (widget.playing) {
        _ctrl.repeat();
      } else {
        _ctrl.stop();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) {
          final t = _ctrl.value;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _bar(t, 0.00),
              const SizedBox(width: 2),
              _bar(t, 0.33),
              const SizedBox(width: 2),
              _bar(t, 0.66),
            ],
          );
        },
      ),
    );
  }

  Widget _bar(double t, double phase) {
    // Paused: short flat bar; playing: bounce between 25% and 100% height.
    final value = widget.playing ? (0.5 + 0.5 * sin((t + phase) * 2 * pi)) : 0.25;
    final h = widget.size * (0.25 + 0.75 * value);
    return Container(
      width: 3,
      height: h,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
