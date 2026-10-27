import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;

import '../app/device.dart';
import 'engine.dart';
import 'play_request.dart';
import 'playback_controller.dart';
import 'playback_watch.dart';
import 'player_gestures.dart';
import 'player_options.dart';
import 'player_prefs.dart';
import 'player_system.dart';
import 'player_tv.dart';
import 'up_next.dart';

enum LevelKind { brightness, volume }

/// Everything the player screen shows and does, on top of the [PlaybackController]: the controls, the touch gestures and their
/// feedback, channel zapping and the next episode through the [PlayerHost], and the system around it ([PlayerSystem]).
/// It is the counterpart of PhonePlayer.swift; the widgets only draw what is here.
class PlayerModel extends ChangeNotifier {
  PlayerModel({
    required this.host,
    required this.request,
    required PlaybackEngine engine,
    required this.system,
    required this.prefs,
    Duration? tickInterval = const Duration(milliseconds: 250),
    UpNext? upNext,
    DateTime Function() clock = DateTime.now,
    this.canRotate = false,
  })  : _now = clock,
        core = PlaybackController(engine, tickInterval: tickInterval, clock: clock),
        upNext = upNext ?? UpNext(),
        controls = ControlsVisibility(now: clock(), hideAfter: Duration(milliseconds: (prefs.barsHideSeconds * 1000).round())),
        videoScale = prefs.videoScale,
        subScale = prefs.subScale,
        subDelay = prefs.subDelay {
    // A remote is slower than a finger: on a TV the controls stay at least 5 s after the last key (0 = never hide stays 0).
    if (isTelevision && controls.hideAfter > Duration.zero && controls.hideAfter < tvHideAfter) controls.hideAfter = tvHideAfter;
    engine.setBuffer(prefs.bufferSize.maxBytes, prefs.bufferSize.readaheadSecs);
    _applySubtitleStyle();
    core.onSaveProgress = _save;
    core.onEndChanged = _endChanged;
    core.onSleep = close;
    core.addListener(_pulse);
    if (isTelevision) tvExitHooks.add(close); // a long press of Back leaves the app: stop and save first
    this.upNext.addListener(notifyListeners);
    _subs = [
      system.pipChanges.stream.listen(_pipChanged),
      system.pipActions.stream.listen((_) => togglePause()),
    ];
    _refreshQueues();
    unawaited(system.isPipSupported().then((v) {
      pipSupported = v;
      notifyListeners();
    }));
    unawaited(system
        .activate(PlayerCommands(
          play: () => setPlaying(true),
          pause: () => setPlaying(false),
          skip: skip,
          seek: seekTo,
          next: goNext,
          previous: previous,
          stop: close,
          isPlaying: () => !core.paused,
          seekStep: prefs.seekStep,
        ))
        .catchError((Object _) {}).whenComplete(_start));
  }

  final PlayerHost host;
  final DateTime Function() _now;
  PlayRequest request;
  final PlaybackController core;
  final PlayerSystem system;
  final PlayerPrefs prefs;
  final UpNext upNext;
  final ControlsVisibility controls;
  final seekRepeat = SeekRepeat(); // TV remote: a held Left/Right/fast-forward key seeks faster

  bool scrubbing = false; // the seek bar or a horizontal drag is active
  bool sheetOpen = false; // a menu or sheet is up
  bool boosting = false; // long press: 2x while held
  bool pipActive = false;
  bool pipSupported = false;
  bool portrait = false; // the rotate button turned the screen upright
  bool fullscreen = false; // the Windows window fills the screen
  double _volume = 1; // engine volume on a desktop (0...1); a phone uses the system volume
  double _volumeBeforeMute = 1;
  final bool canRotate; // phones only: a tablet already follows the device
  bool canZapNext = false;
  bool canZapPrevious = false;
  bool hasNextEpisode = false;
  ({TouchSide side, String label, int id})? skipHud;
  ({LevelKind kind, double value, int id})? levelHud;
  ({VideoScale scale, int id})? toast;
  ({double time, double delta})? dragScrub;
  VideoScale videoScale;
  double subScale;
  double subDelay;
  String? programme;

  final _skipper = SkipAccumulator();
  final _hudTimers = <String, Timer>{};
  Timer? _pipTimer;
  late final List<StreamSubscription<Object?>> _subs;
  int _hudSerial = 0;
  double _scrubStart = 0;
  double? _levelStart;
  double _speedBeforeBoost = 1;
  double _remoteTotal = 0;
  DateTime? _remoteAt;
  bool _closed = false;
  bool _wasPaused = true;
  double _lastAspect = 0;
  DateTime _programmeAt = DateTime.fromMillisecondsSinceEpoch(0);

  void _save(double position, double duration) => host.saveProgress(request, position, duration);

  // The media session is up (audio focus taken) before the first load: another app's audio stops cleanly, not mid-stream.
  void _start() {
    if (!_closed) core.play(request.url.toString(), live: request.isLive, start: request.start);
  }

  bool get closed => _closed;
  DateTime get now => _now();
  bool get isLive => request.isLive;

  /// The first line of text under the title: the programme on now (live) or the request's own subtitle.
  String? get subtitle => (isLive ? programme : null) ?? request.subtitle;

  // What is shown

  bool get holdControls => core.paused || core.atEnd || scrubbing || sheetOpen || core.failed || upNext.isCounting;
  bool get controlsVisible => !pipActive && (controls.shown || holdControls);

  void touchControls() {
    controls.touch(_now());
    notifyListeners();
  }

  void _pulse() {
    if (_closed) return;
    controls.tick(_now(), holding: holdControls);
    system.setAwake(!core.paused);
    final now = _now();
    if (now.difference(_programmeAt) >= const Duration(seconds: 5)) {
      _programmeAt = now; // the host looks the guide and the queues up: not four times a second
      programme = isLive ? host.liveProgramme(request) : null;
      _refreshQueues();
    }
    system.updateNowPlaying(NowPlaying(
      title: request.title,
      subtitle: subtitle,
      isLive: isLive,
      position: core.position,
      duration: core.duration,
      speed: core.speed,
      paused: core.paused,
      buffering: core.buffering,
      canNext: isLive ? canZapNext : hasNextEpisode,
      canPrevious: isLive && canZapPrevious,
    ));
    final aspect = core.engine.aspect;
    if (_wasPaused != core.paused || (aspect - _lastAspect).abs() > 0.01) {
      _wasPaused = core.paused;
      _lastAspect = aspect;
      system.updatePip(aspect: aspect, playing: !core.paused, autoEnter: !core.paused);
    }
    notifyListeners();
  }

  // Transport

  void togglePause() {
    system.userChose();
    core.togglePause();
    touchControls();
  }

  void setPlaying(bool on) {
    core.setPlaying(on);
  }

  /// A play or pause key on the remote: like the button, the user's choice wins over an automatic resume, and the controls show.
  void remotePlay(bool on) {
    system.userChose();
    core.setPlaying(on);
    touchControls();
  }

  /// Previous: the previous channel; a movie or episode starts again (the host knows no previous episode).
  void previous() => isLive ? zap(-1) : seekTo(0);

  /// A key was pressed on the remote: the controls (if up) stay up for another while.
  void keyActivity() {
    if (controls.shown) controls.touch(_now());
  }

  /// Back on a TV remote: first the countdown or the controls go away, then the player closes (everywhere else it closes at once).
  void back() {
    if (isTelevision) {
      if (scrubbing) return scrubEnded(commit: false);
      if (upNext.isCounting) return upNext.cancel();
      if (controls.shown && !holdControls) {
        controls.hide();
        return notifyListeners();
      }
    }
    close();
  }

  /// Desktop: the mouse wheel and Up/Down change the volume in steps; the level shows like the swipe's.
  void volumeBy(double delta) => _setVolume(_volume + delta);

  void toggleMute() => _setVolume(_volume > 0 ? 0 : (_volumeBeforeMute > 0 ? _volumeBeforeMute : 1));

  void _setVolume(double v) {
    if (_volume > 0) _volumeBeforeMute = _volume;
    _volume = v.clamp(0.0, 1.0);
    core.engine.setVolume(_volume);
    levelHud = (kind: LevelKind.volume, value: _volume, id: ++_hudSerial);
    final id = _hudSerial;
    _hudTimers['level']?.cancel();
    _hudTimers['level'] = Timer(const Duration(milliseconds: 900), () {
      if (levelHud?.id == id) {
        levelHud = null;
        notifyListeners();
      }
    });
    touchControls();
  }

  Future<void> toggleFullscreen() async {
    fullscreen = !fullscreen;
    notifyListeners();
    await system.setFullscreen(fullscreen);
  }

  /// Esc on the desktop: leaves full screen first, then closes the player.
  void escape() => fullscreen ? unawaited(toggleFullscreen()) : back();

  /// A seek key on the remote (movies and episodes): [seconds] back (negative) or forward, with the running total as feedback.
  void remoteSeek(double seconds) {
    if (isLive || seconds == 0) return;
    final now = _now();
    final chain = _remoteAt != null && now.difference(_remoteAt!) < SkipAccumulator.window && _remoteTotal.isNegative == seconds.isNegative;
    _remoteTotal = chain ? _remoteTotal + seconds : seconds;
    _remoteAt = now;
    core.seekBy(seconds);
    _show('skip', () => skipHud = (side: seconds < 0 ? TouchSide.left : TouchSide.right, label: SkipAccumulator.label(_remoteTotal.round()), id: ++_hudSerial), () => skipHud = null);
  }

  /// Left/Right on the focused seek bar: moves the target by [seconds]; Select ([scrubEnded]) or a pause in the keys commits it.
  void remoteScrub(double seconds) {
    if (isLive || core.duration <= 0) return;
    if (!scrubbing) scrubBegan();
    barScrubChanged(((dragScrub?.time ?? core.position) + seconds).clamp(0.0, core.duration));
  }

  void seekTo(double t) => core.seekTo(t);
  void skip(double s) => core.seekBy(s);
  void retry() => core.retry();

  /// The user (or the sleep timer, the notification) closed the player: tears everything down, then tells the shell to pop the screen.
  void close() {
    if (_closed) return;
    shutdown();
    host.closePlayer();
  }

  /// Saves the position and tears everything down without telling the shell (the screen is already gone). Idempotent.
  void shutdown() {
    if (_closed) return;
    _closed = true;
    tvExitHooks.remove(close);
    core.close(); // saves the position
    upNext.cancel();
    _pipTimer?.cancel();
    for (final t in _hudTimers.values) {
      t.cancel();
    }
    for (final s in _subs) {
      s.cancel();
    }
    system.restoreBrightness();
    unawaited(system.deactivate());
    unawaited(system.exit());
  }

  /// The next channel or episode on the same player: the old position is saved first (PlaybackController.play).
  void replace(PlayRequest r) {
    if (_closed) return;
    upNext.cancel();
    core.play(r.url.toString(), live: r.isLive, start: r.start); // saves the old position, so `request` must still be the old one
    request = r;
    _programmeAt = DateTime.fromMillisecondsSinceEpoch(0);
    _refreshQueues();
    touchControls();
  }

  // Channels and episodes

  void zap(int step) {
    final next = host.zap(request, step);
    if (next != null) replace(next);
  }

  void goNext() {
    if (isLive) {
      zap(1);
    } else {
      playUpNextNow();
    }
  }

  void _refreshQueues() {
    canZapNext = isLive && host.zap(request, 1) != null;
    canZapPrevious = isLive && host.zap(request, -1) != null;
    hasNextEpisode = !isLive && host.nextEpisode(request) != null;
  }

  void _endChanged(bool ended) {
    if (!ended) return upNext.cancel();
    final next = prefs.autoNextEpisode && !isLive ? host.nextEpisode(request) : null;
    if (next == null) return;
    controls.touch(_now());
    upNext.begin(next, replace);
  }

  void playUpNextNow() {
    final next = upNext.next ?? (isLive ? null : host.nextEpisode(request));
    if (next == null) return;
    replace(next);
  }

  // Subtitles, audio, speed, scale

  void _applySubtitleStyle() => core.engine.setSubtitleStyle(scale: subScale, delay: subDelay);

  int get subtitleSelection => core.tracks.where((t) => t.type == 'sub' && t.selected).firstOrNull?.id ?? 0;
  int get audioSelection => core.tracks.where((t) => t.type == 'audio' && t.selected).firstOrNull?.id ?? 0;

  void selectSubtitle(int id) {
    core.engine.selectSubtitle(id);
    notifyListeners();
  }

  void selectAudio(int id) {
    core.engine.selectAudio(id);
    notifyListeners();
  }

  void addSubtitle(String path) => core.engine.addSubtitle(path);

  void setSubtitleStyle({double? scale, double? delay}) {
    subScale = scale ?? subScale;
    subDelay = delay ?? subDelay;
    prefs
      ..subScale = subScale
      ..subDelay = subDelay;
    _applySubtitleStyle();
    unawaited(prefs.saveLook());
    notifyListeners();
  }

  void setSpeed(double s) => core.setSpeed(s);
  void setSleep(int minutes) => core.setSleep(minutes);

  void setVideoScale(VideoScale s) {
    videoScale = s;
    prefs.videoScale = s;
    unawaited(prefs.saveLook());
    notifyListeners();
  }

  /// A menu or sheet is open: the controls stay until it closes.
  Future<T?> withSheet<T>(Future<T?> Function() open) async {
    sheetOpen = true;
    notifyListeners();
    try {
      return await open();
    } finally {
      sheetOpen = false;
      controls.touch(_now());
      notifyListeners();
    }
  }

  // Picture in Picture

  /// The rotate button: upright and back to landscape, until the player closes.
  Future<void> toggleOrientation() async {
    portrait = !portrait;
    notifyListeners();
    await system.setPortrait(portrait);
    touchControls();
  }

  Future<void> startPip() async {
    if (await system.enterPip(aspect: core.engine.aspect, playing: !core.paused)) touchControls();
  }

  void _pipChanged(bool on) {
    pipActive = on;
    if (!on) {
      controls.touch(_now());
      // The window was dismissed with its X (the app is not coming back to the front): stop playing. Expanding it brings the app back.
      _pipTimer?.cancel();
      _pipTimer = Timer(const Duration(milliseconds: 400), () {
        final state = WidgetsBinding.instance.lifecycleState;
        if (!_closed && state != null && state != AppLifecycleState.resumed) setPlaying(false);
      });
    }
    notifyListeners();
  }

  /// The app went to the background: save now (it may be killed without notice).
  void appPaused() => core.saveNow();

  // Gestures (all called by the gesture surface on the main isolate)

  /// A single tap on the picture: another skip while a double-tap chain is running, else show/hide the controls.
  void singleTap(TouchSide side) {
    if (!isLive && _skipper.isChaining(_now())) {
      _skipTapped(side);
    } else {
      controls.toggle(_now());
      notifyListeners();
    }
  }

  void doubleTap(TouchSide side) {
    if (!isLive) _skipTapped(side);
  }

  void _skipTapped(TouchSide side) {
    final total = _skipper.skip(side, step: prefs.seekStep, now: _now());
    core.seekBy((side == TouchSide.left ? -prefs.seekStep : prefs.seekStep).toDouble());
    _show('skip', () => skipHud = (side: side, label: SkipAccumulator.label(total), id: ++_hudSerial), () => skipHud = null);
  }

  void scrubBegan() {
    if (isLive || core.duration <= 0) return;
    scrubbing = true;
    _scrubStart = core.position;
    dragScrub = (time: core.position, delta: 0);
    controls.touch(_now());
    notifyListeners();
  }

  void scrubChanged(double translation, double width) {
    if (!scrubbing) return;
    final t = PlayerGestures.scrubTarget(start: _scrubStart, translation: translation, width: width, duration: core.duration);
    dragScrub = (time: t, delta: t - _scrubStart);
    notifyListeners();
  }

  /// The seek bar itself is dragged (a horizontal drag on the picture goes through [scrubBegan]).
  void barScrubChanged(double time) {
    if (!scrubbing) return;
    dragScrub = (time: time, delta: time - _scrubStart);
    notifyListeners();
  }

  void scrubEnded({required bool commit}) {
    if (!scrubbing) return;
    final t = dragScrub?.time;
    if (commit && t != null) core.seekTo(t);
    dragScrub = null;
    scrubbing = false;
    notifyListeners();
  }

  Future<void> levelBegan(TouchSide side) async {
    _levelStart = null;
    if (isTelevision) return; // a TV has no brightness to swipe and the volume belongs to the remote
    final kind = side == TouchSide.left ? LevelKind.brightness : LevelKind.volume;
    final v = await (kind == LevelKind.brightness ? system.brightness() : system.volume());
    _levelStart = v ?? 0.5;
    levelHud = (kind: kind, value: _levelStart!, id: _hudSerial);
    notifyListeners();
  }

  void levelChanged(TouchSide side, double translationY, double height) {
    final start = _levelStart;
    if (start == null) return;
    final v = PlayerGestures.level(start: start, translationY: translationY, height: height);
    final kind = side == TouchSide.left ? LevelKind.brightness : LevelKind.volume;
    _applyLevel(kind, v);
    levelHud = (kind: kind, value: v, id: ++_hudSerial);
    notifyListeners();
  }

  /// A long fast flick down closes the player (and the level the drag moved is put back); anything else keeps the new level.
  void levelEnded(TouchSide side, double translationY, double velocityY) {
    final start = _levelStart;
    final kind = side == TouchSide.left ? LevelKind.brightness : LevelKind.volume;
    _levelStart = null;
    if (start != null && PlayerGestures.verticalEnd(translationY, velocityY) == VerticalEnd.dismiss) {
      _applyLevel(kind, start);
      levelHud = null;
      close();
      return;
    }
    final id = _hudSerial;
    _hudTimers['level']?.cancel();
    _hudTimers['level'] = Timer(const Duration(milliseconds: 900), () {
      if (levelHud?.id == id) {
        levelHud = null;
        notifyListeners();
      }
    });
  }

  void _applyLevel(LevelKind kind, double v) => kind == LevelKind.brightness ? system.setBrightness(v) : system.setVolume(v);

  /// The pinch is over: fit -> fill -> stretch by how far it went.
  void pinchEnded(double scale) {
    final next = PlayerGestures.scale(scale, videoScale);
    if (next == videoScale) return;
    setVideoScale(next);
    _show('toast', () => toast = (scale: next, id: ++_hudSerial), () => toast = null);
  }

  /// Long press: 2x while the finger stays down (movies and episodes only).
  void hold({required bool down}) {
    if (isLive) return;
    if (down && !boosting) {
      boosting = true;
      _speedBeforeBoost = core.speed;
      core.setSpeed(2);
    } else if (!down && boosting) {
      boosting = false;
      core.setSpeed(_speedBeforeBoost);
    }
    notifyListeners();
  }

  void _show(String key, void Function() set, void Function() clear) {
    set();
    final shown = key == 'skip' ? skipHud?.id : toast?.id;
    _hudTimers[key]?.cancel();
    _hudTimers[key] = Timer(const Duration(milliseconds: 800), () {
      if ((key == 'skip' ? skipHud?.id : toast?.id) == shown) {
        clear();
        notifyListeners();
      }
    });
    notifyListeners();
  }

  @override
  void dispose() {
    shutdown();
    core.removeListener(_pulse);
    upNext.removeListener(notifyListeners);
    upNext.dispose();
    core.dispose();
    super.dispose();
  }
}
