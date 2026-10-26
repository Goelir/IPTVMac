import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:iptvmac/app/device.dart';
import 'package:iptvmac/ui/bidi.dart';
import 'missing_strings.dart';
import 'package:flutter_localized_locales/flutter_localized_locales.dart';

import '../l10n/app_localizations.dart';
import 'player_model.dart';
import 'player_options.dart';
import 'player_seek_bar.dart';
import 'player_sheets.dart';
import 'player_tv.dart';
import 'player_widgets.dart';
import 'playback_speed.dart';
import 'track_label.dart';

/// Close, title and programme, favourite star, Picture in Picture.
class PlayerTopBar extends StatelessWidget {
  const PlayerTopBar({super.key, required this.model});
  final PlayerModel model;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final item = model.request.item;
    final subtitle = model.subtitle;
    final favorite = item != null && model.host.isFavorite(item);
    return Row(children: [
      PlayerButton(icon: Icons.close, label: l.playerClose, onPressed: model.close, filled: true),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(model.request.title, textDirection: titleDirection(model.request.title), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, shadows: _shadow))),
            if (model.core.quality case final q?) ...[const SizedBox(width: 8), QualityBadge(q)],
          ]),
          if (subtitle != null && subtitle.isNotEmpty)
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13, shadows: _shadow)),
        ]),
      ),
      if (item != null && model.host.hasDetails(item))
        PlayerButton(
          icon: Icons.info_outline,
          label: l.infoDetails,
          onPressed: () {
            model.host.showDetails(item);
            model.touchControls();
          },
        ),
      if (item != null)
        PlayerButton(
          icon: favorite ? Icons.star : Icons.star_border,
          label: favorite ? l.favRemove : l.favAdd,
          color: favorite ? Colors.amber : Colors.white,
          onPressed: () async {
            await model.host.toggleFavorite(item);
            model.touchControls();
          },
        ),
      if (model.pipSupported && !isTelevision) PlayerButton(icon: Icons.picture_in_picture_alt, label: l.playerPip, onPressed: model.startPip),
      if (model.canRotate && !isTelevision)
        PlayerButton(
          icon: model.portrait ? Icons.stay_current_landscape : Icons.stay_current_portrait,
          label: MissingStrings.rotateScreen,
          onPressed: model.toggleOrientation,
        ),
    ]);
  }
}

const _shadow = [Shadow(color: Colors.black54, blurRadius: 4)];

/// Skip back / play / skip forward for movies; previous channel / play / next channel for live. Not mirrored in right-to-left languages.
class PlayerTransport extends StatelessWidget {
  const PlayerTransport({super.key, required this.model, this.playFocus});
  final PlayerModel model;
  final FocusNode? playFocus; // the play button's node: the TV key layer puts the focus there

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final step = model.prefs.seekStep;
    final core = model.core;
    final ended = core.atEnd && !model.isLive;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (model.isLive)
          PlayerButton(icon: Icons.skip_previous, label: l.playerChannelPrev, size: 32, onPressed: model.canZapPrevious ? () => model.zap(-1) : null)
        else
          PlayerButton(
            icon: _skipIcon(step, back: true),
            label: l.playerSkipBack(l.unitSeconds(step)),
            size: 40,
            onPressed: () {
              model.skip(-step.toDouble());
              model.touchControls();
            },
          ),
        SizedBox(width: model.isLive ? 24 : 36),
        _PlayPause(model: model, ended: ended, focusNode: playFocus),
        SizedBox(width: model.isLive ? 24 : 36),
        if (model.isLive)
          PlayerButton(icon: Icons.skip_next, label: l.playerChannelNext, size: 32, onPressed: model.canZapNext ? () => model.zap(1) : null)
        else
          PlayerButton(
            icon: _skipIcon(step, back: false),
            label: l.playerSkipForward(l.unitSeconds(step)),
            size: 40,
            onPressed: () {
              model.skip(step.toDouble());
              model.touchControls();
            },
          ),
      ]),
    );
  }

  static IconData _skipIcon(int step, {required bool back}) => switch (step) {
        5 => back ? Icons.replay_5 : Icons.forward_5,
        30 => back ? Icons.replay_30 : Icons.forward_30,
        _ => back ? Icons.replay_10 : Icons.forward_10,
      };
}

class _PlayPause extends StatelessWidget {
  const _PlayPause({required this.model, required this.ended, this.focusNode});
  final PlayerModel model;
  final bool ended;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final core = model.core;
    final waiting = core.buffering && !core.paused;
    return Semantics(
      button: true,
      label: ended ? l.playerReplay : (core.paused ? l.downloadsPlay : l.downloadsPause),
      child: tvFocusable(
        focusNode: focusNode,
        radius: 40,
        onActivate: () => ended ? core.replay() : model.togglePause(),
        child: GestureDetector(
        onTap: () => ended ? core.replay() : model.togglePause(),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.55),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: waiting
              ? const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
              : Icon(ended ? Icons.replay : (core.paused ? Icons.play_arrow : Icons.pause), color: Colors.white, size: 40),
        ),
      )),
    );
  }
}

/// The seek row and, under it, speed (movies), subtitles, audio, video scale and the sleep timer.
class PlayerBottomPanel extends StatelessWidget {
  const PlayerBottomPanel({super.key, required this.model, this.subtitlesFocus});
  final PlayerModel model;
  final FocusNode? subtitlesFocus; // the subtitles button's node: the TV key layer puts the focus there

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final core = model.core;
    final left = core.sleepMinutesLeft;
    final subs = core.tracks.where((t) => t.type == 'sub').toList();
    final audio = core.tracks.where((t) => t.type == 'audio').toList();
    final names = LocaleNames.of(context);
    String name(Track t) => TrackLabel.text(t, languageName: names?.nameOf);
    return PlayerSurface(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        PlayerSeekRow(model: model),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          if (!model.isLive)
            _Utility(
              label: l.playerSpeed,
              onTap: (_) => showSpeedSheet(context, model),
              child: Text(PlaybackSpeed.label(core.speed), style: TextStyle(color: core.speed == 1 ? Colors.white : Colors.amber, fontWeight: FontWeight.bold)),
            ),
          _Utility(
            label: l.playerSubtitles,
            focusNode: subtitlesFocus,
            icon: model.subtitleSelection == 0 ? Icons.closed_caption_outlined : Icons.closed_caption,
            onTap: (anchor) async {
              final picked = await _showMenu<int>(anchor, model, [
                _check(0, l.playerOff, model.subtitleSelection == 0),
                for (final t in subs) _check(t.id, name(t), t.id == model.subtitleSelection),
                const PopupMenuDivider(),
                PopupMenuItem(value: -1, child: Text(l.playerAddSubtitle)),
                PopupMenuItem(value: -2, child: Text(l.playerSubtitleAdjust)),
              ]);
              if (picked == null || !context.mounted) return;
              if (picked == -1) {
                await model.withSheet(() async {
                  // ponytail: any file type, the picker cannot filter .srt by MIME type on Android; mpv ignores what it cannot read
                  final file = await FilePicker.pickFile();
                  if (file?.path != null) model.addSubtitle(file!.path!);
                  return null;
                });
              } else if (picked == -2) {
                await showSubtitleAdjustSheet(context, model);
              } else {
                model.selectSubtitle(picked);
              }
            },
          ),
          _Utility(
            label: l.playerAudio,
            icon: Icons.volume_up_outlined,
            onTap: audio.isEmpty
                ? null
                : (anchor) async {
                    final picked = await _showMenu<int>(anchor, model, [for (final t in audio) _check(t.id, name(t), t.id == model.audioSelection)]);
                    if (picked != null) model.selectAudio(picked);
                  },
          ),
          _Utility(
            label: '${l.settingsVideoScale}: ${scaleName(l, model.videoScale)}',
            icon: model.videoScale == VideoScale.fit ? Icons.fit_screen : Icons.crop_free,
            onTap: (anchor) async {
              final picked = await _showMenu<VideoScale>(anchor, model, [for (final s in VideoScale.values) _check(s, scaleName(l, s), s == model.videoScale)]);
              if (picked != null) model.setVideoScale(picked);
            },
          ),
          _Utility(
            label: l.playerSleep,
            icon: left == null ? Icons.bedtime_outlined : Icons.bedtime,
            color: left == null ? Colors.white : Colors.amber,
            text: left == null ? null : l.unitMinutesShort(left),
            onTap: (anchor) async {
              final picked = await _showMenu<int>(anchor, model, [
                _check(0, l.playerOff, left == null),
                for (final m in const [15, 30, 45, 60, 90, 120]) PopupMenuItem(value: m, child: Text(l.unitMinutes(m))),
              ]);
              if (picked != null) model.setSleep(picked);
            },
          ),
        ]),
      ]),
    );
  }

  static PopupMenuItem<T> _check<T>(T value, String text, bool selected) => PopupMenuItem<T>(
        value: value,
        child: Row(children: [
          SizedBox(width: 28, child: selected ? const Icon(Icons.check, size: 18) : null),
          Flexible(child: Text(text)),
        ]),
      );
}

/// A menu that opens over the button that was tapped; the controls stay up while it is open.
Future<T?> _showMenu<T>(BuildContext anchor, PlayerModel model, List<PopupMenuEntry<T>> items) {
  final box = anchor.findRenderObject()! as RenderBox;
  final overlay = Overlay.of(anchor).context.findRenderObject()! as RenderBox;
  final rect = Rect.fromPoints(box.localToGlobal(Offset.zero, ancestor: overlay), box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay));
  return model.withSheet(() => showMenu<T>(context: anchor, position: RelativeRect.fromRect(rect, Offset.zero & overlay.size), items: items));
}

class _Utility extends StatelessWidget {
  const _Utility({required this.label, required this.onTap, this.icon, this.child, this.text, this.color = Colors.white, this.focusNode});
  final FocusNode? focusNode;
  final String label;
  final void Function(BuildContext anchor)? onTap;
  final IconData? icon;
  final Widget? child;
  final String? text;
  final Color color;

  @override
  Widget build(BuildContext context) => Builder(
        builder: (anchor) => Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: tvRing(radius: 12, InkResponse(
            focusNode: focusNode,
            canRequestFocus: onTap != null, // a disabled button is not a stop for the D-pad
            onTap: onTap == null ? null : () => onTap!(anchor),
            radius: 28,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
              child: Center(
                child: child ??
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, color: onTap == null ? Colors.white30 : color, size: 24),
                      if (text != null) Padding(padding: const EdgeInsetsDirectional.only(start: 4), child: Text(text!, style: TextStyle(color: color, fontSize: 13))),
                    ]),
              ),
            ),
          )),
        ),
      );
}

/// The picture's quality tag ("4K", "FHD", "HD", "SD") next to the title.
class QualityBadge extends StatelessWidget {
  const QualityBadge(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(border: Border.all(color: Colors.white.withValues(alpha: 0.85)), borderRadius: BorderRadius.circular(4)),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, height: 1.2)),
      );
}
