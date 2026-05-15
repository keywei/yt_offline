import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/settings_providers.dart';
import '../../../../core/i18n/strings.dart';
import '../../../../core/storage/preferences_store.dart';

class SubtitleSettingsScreen extends ConsumerWidget {
  const SubtitleSettingsScreen({super.key});

  static const _colorChoices = <int>[
    0xFFFFFFFF, // white
    0xFFFFEB3B, // yellow
    0xFF4FC3F7, // cyan
    0xFF81C784, // green
    0xFFFF8A65, // orange
    0xFFE57373, // red
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final prefs = ref.watch(appPreferencesProvider).valueOrNull ??
        AppPreferences.defaults;
    final notifier = ref.read(appPreferencesProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(s.subtitleSettingsTitle)),
      body: ListView(
        children: [
          _section(context, s.subtitlePreview),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _Preview(prefs: prefs),
          ),
          const Divider(height: 1),
          _section(context, s.subtitleFontSizeLabel),
          _SliderRow(
            value: prefs.subtitleFontSize,
            min: 20,
            max: 120,
            divisions: 20,
            label: prefs.subtitleFontSize.toInt().toString(),
            onChanged: (v) => notifier.setSubtitleStyle(fontSize: v),
          ),
          const Divider(height: 1),
          _section(context, s.subtitleColorLabel),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final argb in _colorChoices)
                  _ColorSwatch(
                    argb: argb,
                    selected: prefs.subtitleColorArgb == argb,
                    onTap: () => notifier.setSubtitleStyle(colorArgb: argb),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          _section(context, s.subtitleBackgroundLabel),
          _SliderRow(
            value: prefs.subtitleBackgroundAlpha,
            min: 0,
            max: 1,
            divisions: 10,
            label: '${(prefs.subtitleBackgroundAlpha * 100).toInt()}%',
            onChanged: (v) => notifier.setSubtitleStyle(backgroundAlpha: v),
          ),
          const Divider(height: 1),
          _section(context, s.subtitlePositionLabel),
          _SliderRow(
            value: prefs.subtitlePosition.toDouble(),
            min: 0,
            max: 100,
            divisions: 10,
            label: switch (prefs.subtitlePosition) {
              < 33 => s.subtitlePosTop,
              > 66 => s.subtitlePosBottom,
              _ => s.subtitlePosMiddle,
            },
            onChanged: (v) =>
                notifier.setSubtitleStyle(position: v.round()),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge,
        ),
      );
}

class _SliderRow extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
            SizedBox(
              width: 56,
              child: Text(label, textAlign: TextAlign.right),
            ),
          ],
        ),
      );
}

class _ColorSwatch extends StatelessWidget {
  final int argb;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.argb,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Color(argb),
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.amber : Colors.black26,
              width: selected ? 3 : 1,
            ),
          ),
        ),
      );
}

class _Preview extends StatelessWidget {
  final AppPreferences prefs;
  const _Preview({required this.prefs});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment(0, _alignmentY()),
            child: Container(
              color: Color.fromARGB(
                (prefs.subtitleBackgroundAlpha * 255).round(),
                0,
                0,
                0,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(
                s.subtitlePreviewText,
                style: TextStyle(
                  fontSize: prefs.subtitleFontSize / 3.5,
                  color: Color(prefs.subtitleColorArgb),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _alignmentY() {
    // sub-pos: 0=top, 100=bottom. Map to alignment -0.9..0.9.
    return ((prefs.subtitlePosition / 100) * 1.8) - 0.9;
  }
}
