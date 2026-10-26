import 'package:flutter/material.dart';

import '../app/device.dart';
import '../l10n/app_localizations.dart';
import 'player_model.dart';
import 'playback_speed.dart';
import 'player_tv.dart';

/// Playback speed: the presets as chips, a slider for in-between values and a reset (movies only).
Future<void> showSpeedSheet(BuildContext context, PlayerModel model) => model.withSheet(() => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => tvDirectional(c, ListenableBuilder(listenable: model, builder: (context, _) => _SpeedSheet(model: model))),
    ));

class _SpeedSheet extends StatelessWidget {
  const _SpeedSheet({required this.model});
  final PlayerModel model;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final speed = model.core.speed;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(l.playerSpeed, style: Theme.of(context).textTheme.titleMedium)),
            Text(PlaybackSpeed.label(speed), style: Theme.of(context).textTheme.titleLarge?.copyWith(color: speed == 1 ? null : Colors.amber)),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final v in PlaybackSpeed.presets)
              ChoiceChip(
                autofocus: isTelevision && (PlaybackSpeed.presets.any((p) => (p - speed).abs() < 0.001) ? (v - speed).abs() < 0.001 : v == 1), // a sheet starts on the speed in use
                label: Text(PlaybackSpeed.label(v)),
                selected: (v - speed).abs() < 0.001,
                onSelected: (_) => model.setSpeed(v),
              ),
          ]),
          Row(children: [
            const Icon(Icons.hourglass_bottom, size: 18),
            Expanded(
              child: Slider(
                value: speed.clamp(PlaybackSpeed.min, PlaybackSpeed.max),
                min: PlaybackSpeed.min,
                max: PlaybackSpeed.max,
                semanticFormatterCallback: PlaybackSpeed.label,
                onChanged: model.setSpeed,
              ),
            ),
            const Icon(Icons.bolt, size: 18),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            OutlinedButton(onPressed: speed == 1 ? null : () => model.setSpeed(1), child: Text(l.playerSpeedReset)),
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.playerClose)),
          ]),
        ]),
      ),
    );
  }
}

/// Subtitle size and delay, applied while the sheet is open so the effect shows on the picture behind it.
Future<void> showSubtitleAdjustSheet(BuildContext context, PlayerModel model) => model.withSheet(() => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => tvDirectional(c, ListenableBuilder(listenable: model, builder: (context, _) => _SubtitleAdjustSheet(model: model))),
    ));

class _SubtitleAdjustSheet extends StatelessWidget {
  const _SubtitleAdjustSheet({required this.model});
  final PlayerModel model;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    double tenth(double v, double lo, double hi) => (v.clamp(lo, hi) * 10).roundToDouble() / 10;
    final scale = model.subScale;
    final delay = model.subDelay;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.playerSubtitleAdjust, style: Theme.of(context).textTheme.titleMedium),
          _Stepper(
            autofocus: true,
            label: l.settingsSubscale,
            value: '${(scale * 100).round()}%',
            onMinus: () => model.setSubtitleStyle(scale: tenth(scale - 0.1, 0.5, 2)),
            onPlus: () => model.setSubtitleStyle(scale: tenth(scale + 0.1, 0.5, 2)),
          ),
          _Stepper(
            label: l.settingsSubdelay,
            value: '${delay >= 0 ? '+' : ''}${delay.toStringAsFixed(1)}',
            onMinus: () => model.setSubtitleStyle(delay: tenth(delay - 0.1, -10, 10)),
            onPlus: () => model.setSubtitleStyle(delay: tenth(delay + 0.1, -10, 10)),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            OutlinedButton(
              onPressed: scale == 1 && delay == 0 ? null : () => model.setSubtitleStyle(scale: 1, delay: 0),
              child: Text(l.playerSpeedReset),
            ),
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.playerClose)),
          ]),
        ]),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.value, required this.onMinus, required this.onPlus, this.autofocus = false});
  final bool autofocus;
  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(label)),
        IconButton(onPressed: onMinus, icon: const Icon(Icons.remove_circle_outline), tooltip: '−'),
        SizedBox(width: 56, child: Text(value, textAlign: TextAlign.center, style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]))),
        IconButton(autofocus: autofocus && isTelevision, onPressed: onPlus, icon: const Icon(Icons.add_circle_outline), tooltip: '+'),
      ]);
}
