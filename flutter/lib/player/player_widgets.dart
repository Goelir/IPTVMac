import 'package:flutter/material.dart';

import '../app/device.dart';
import '../l10n/app_localizations.dart';
import 'player_gestures.dart';
import 'player_model.dart';
import 'player_options.dart';
import 'player_tv.dart';
import 'seek_bar_math.dart';

/// The dark translucent panel behind the player's controls (like the iPhone player).
class PlayerSurface extends StatelessWidget {
  const PlayerSurface({super.key, required this.child, this.radius = 16, this.padding = EdgeInsets.zero});
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: child,
      );
}

/// A round icon button with a 48 dp touch target and an accessible label.
class PlayerButton extends StatelessWidget {
  const PlayerButton({super.key, required this.icon, required this.label, required this.onPressed, this.color = Colors.white, this.size = 26, this.filled = false});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) => tvRing(IconButton(
        onPressed: onPressed,
        tooltip: label,
        iconSize: size,
        color: color,
        disabledColor: Colors.white30,
        style: filled
            ? IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.55), side: BorderSide(color: Colors.white.withValues(alpha: 0.12)))
            : null,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: Icon(icon),
      ));
}

String scaleName(AppLocalizations l, VideoScale s) => switch (s) {
      VideoScale.fit => l.playerScaleFit,
      VideoScale.fill => l.playerScaleFill,
      VideoScale.stretch => l.playerScaleStretch,
    };

/// Feedback for the touch gestures: the skip ripple on the tapped side, the brightness/volume level, a toast (video scale),
/// the 2x badge while holding and the time card while scrubbing. None of it takes touches.
class PlayerHud extends StatelessWidget {
  const PlayerHud({super.key, required this.model});
  final PlayerModel model;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final skip = model.skipHud;
    final level = model.levelHud;
    final drag = model.dragScrub;
    final toast = model.toast;
    return IgnorePointer(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(children: [
          if (skip != null && isTelevision)
            Align(alignment: Alignment.bottomCenter, child: Padding(padding: const EdgeInsets.only(bottom: 140), child: _SeekPill(skip.side, skip.label)))
          else if (skip != null)
            Positioned.fill(child: _SkipRipple(key: ValueKey(skip.id), side: skip.side, label: skip.label)),
          if (level != null) Positioned.fill(child: _LevelHud(kind: level.kind, value: level.value, label: level.kind == LevelKind.brightness ? l.playerBrightness : l.playerVolume)),
          if (drag != null)
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 56),
                child: PlayerSurface(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('${SeekBarMath.format(drag.time)}  (${drag.delta < 0 ? '−' : '+'}${SeekBarMath.format(drag.delta.abs())})',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
                ),
              ),
            ),
          if (model.boosting)
            const Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 56),
                child: PlayerSurface(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.fast_forward, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text('2×', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          if (toast != null)
            Center(
              child: PlayerSurface(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.aspect_ratio, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(scaleName(l, toast.scale), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

/// TV: the seek a key made, small and low: the arrow's direction and the running total ("+10", "+20"...).
class _SeekPill extends StatelessWidget {
  const _SeekPill(this.side, this.label);
  final TouchSide side;
  final String label;

  @override
  Widget build(BuildContext context) => PlayerSurface(
        radius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(side == TouchSide.left ? Icons.fast_rewind : Icons.fast_forward, color: Colors.white, size: 26),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
        ]),
      );
}

/// A soft half-disc on the tapped side with the running total ("+10", "+20"...).
class _SkipRipple extends StatelessWidget {
  const _SkipRipple({super.key, required this.side, required this.label});
  final TouchSide side;
  final String label;

  @override
  Widget build(BuildContext context) {
    final left = side == TouchSide.left;
    final size = MediaQuery.sizeOf(context);
    final d = size.height * 1.8;
    return Align(
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      child: SizedBox(
        width: size.width / 2,
        height: size.height,
        child: Stack(alignment: Alignment.center, children: [
          ClipRect(
            child: OverflowBox(
              maxWidth: d,
              maxHeight: d,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.5, end: 1),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                builder: (_, v, child) => Transform.translate(offset: Offset(left ? -size.width / 4 : size.width / 4, 0), child: Transform.scale(scale: v, child: child)),
                child: Container(width: d, height: d, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.14))),
              ),
            ),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(left ? Icons.fast_rewind : Icons.fast_forward, color: Colors.white, size: 32),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }
}

/// Brightness (left edge) and volume (right edge): a slim vertical level with its icon.
class _LevelHud extends StatelessWidget {
  const _LevelHud({required this.kind, required this.value, required this.label});
  final LevelKind kind;
  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final left = kind == LevelKind.brightness;
    final icon = kind == LevelKind.brightness
        ? (value < 0.5 ? Icons.brightness_low : Icons.brightness_high)
        : (value == 0 ? Icons.volume_off : (value < 0.5 ? Icons.volume_down : Icons.volume_up));
    return Align(
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(left: left ? 28 : 0, right: left ? 0 : 28),
        child: Semantics(
          label: label,
          value: '${(value * 100).round()}%',
          child: PlayerSurface(
            radius: 18,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 10),
              SizedBox(
                width: 6,
                height: 110,
                child: Stack(alignment: Alignment.bottomCenter, children: [
                  Container(decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3))),
                  Container(height: 110 * value < 6 ? 6 : 110 * value, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3))),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The failure card: what went wrong, a hint, Retry and Back.
class PlayerErrorCard extends StatelessWidget {
  const PlayerErrorCard({super.key, required this.model});
  final PlayerModel model;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final reason = model.core.failure;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: _TvScope(child: PlayerSurface(
          radius: 20,
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: Colors.amber, size: 36),
            const SizedBox(height: 10),
            Text(l.playerError, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            if (reason != null && reason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(reason, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
            ],
            const SizedBox(height: 6),
            Text(l.playerErrorHint, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 16),
            Wrap(spacing: 12, runSpacing: 8, alignment: WrapAlignment.center, children: [
              OutlinedButton(onPressed: model.close, child: Text(l.playerBack)),
              FilledButton(autofocus: isTelevision, onPressed: model.retry, child: Text(l.playerRetry)),
            ]),
          ]),
        )),
      ),
    );
  }
}

/// The countdown card for the next episode: the title, "Playing in 5 s", Play now and Cancel.
class UpNextCard extends StatelessWidget {
  const UpNextCard({super.key, required this.model});
  final PlayerModel model;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final next = model.upNext.next;
    if (next == null) return const SizedBox.shrink();
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _TvScope(child: PlayerSurface(
              radius: 18,
              padding: const EdgeInsets.all(14),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text('${l.nextTitle}: ${next.title}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    Text(l.nextIn(model.upNext.secondsLeft), style: const TextStyle(color: Colors.white60, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()])),
                  ]),
                ),
                const SizedBox(width: 12),
                TextButton(onPressed: model.upNext.cancel, child: Text(l.nextCancel)),
                FilledButton(autofocus: isTelevision, onPressed: model.playUpNextNow, child: Text(l.nextNow)),
              ]),
            )),
          ),
        ),
      ),
    );
  }
}

/// A card with buttons on a TV: its own focus scope, so that the button with `autofocus` takes the focus when the card appears
/// (the player's screen holds the focus until then) and the arrows stay among the card's buttons.
class _TvScope extends StatelessWidget {
  const _TvScope({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => isTelevision ? FocusScope(child: child) : child;
}
