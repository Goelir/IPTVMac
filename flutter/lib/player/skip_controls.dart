import 'dart:async';

import '../core/skip_marks.dart';

/// A short message for the player to show for a moment after marking.
enum SkipNotice { saved, refused }

/// The skip buttons of the episode that is playing: the marks of its series, the button to show now, and marking new ones.
/// The player model calls [update] with every tick of its clock and draws [offer]; the menu items call the `mark…` functions.
/// Port of IPTVAppKit/SkipControls.swift.
class SkipControls {
  SkipControls({required this.marks, required this.save, required this.onChange, this.noticeFor = const Duration(seconds: 3)});

  SkipMarks marks;
  SkipOffer? offer;
  SkipNotice? notice;

  /// Keeps the marks of the series (the host writes them to the database).
  final void Function(SkipMarks) save;

  /// Something to redraw changed.
  final void Function() onChange;
  final Duration noticeFor;
  Timer? _noticeTimer;

  void update({required double position, required double duration}) {
    final o = SkipLogic.offer(marks, position: position, duration: duration);
    if (o != offer) {
      offer = o;
      onChange();
    }
  }

  void markIntroStart({required double position, required double duration}) =>
      _apply(SkipLogic.markIntroStart(marks, position: position, duration: duration), position, duration);

  void markIntroEnd({required double position, required double duration}) =>
      _apply(SkipLogic.markIntroEnd(marks, position: position, duration: duration), position, duration);

  void markCredits({required double position, required double duration}) =>
      _apply(SkipLogic.markCredits(marks, position: position, duration: duration), position, duration);

  /// Forgets all three marks of the series.
  void forget() {
    marks = const SkipMarks();
    save(marks);
    offer = null;
    _show(SkipNotice.saved);
  }

  void _apply(SkipMarks? m, double position, double duration) {
    if (m == null) return _show(SkipNotice.refused);
    marks = m;
    save(m);
    offer = SkipLogic.offer(m, position: position, duration: duration);
    _show(SkipNotice.saved);
  }

  void _show(SkipNotice n) {
    notice = n;
    _noticeTimer?.cancel();
    _noticeTimer = Timer(noticeFor, () {
      notice = null;
      onChange();
    });
    onChange();
  }

  void dispose() => _noticeTimer?.cancel();
}
