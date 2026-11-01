import 'dart:async';

import 'package:flutter/foundation.dart';

import 'engine.dart';
import 'playback_speed.dart';
import 'playback_watch.dart';
import 'sleep_timer.dart';
import 'track_label.dart';
import 'video_quality.dart';

/// One playback and the state a player UI shows (position, pause, speed, tracks, buffering, failure), polled four times a second.
/// It carries the rules of the Apple players (Sources/IPTVPlayer/PlaybackController.swift): a dropped live stream is reloaded a few
/// times, a paused live stream that went stale is reloaded on resume, "the movie ended" is reported once, the sleep timer, and
/// progress saving that never writes a 0 position. No UI and no localization in here: [failure] is the engine's reason.
class PlaybackController extends ChangeNotifier {
  /// [tickInterval] null = no timer (tests call [tick]); [retryDelay] is the pause before a live reload.
  PlaybackController(
    this.engine, {
    Duration? tickInterval = const Duration(milliseconds: 250),
    this.retryDelay = LiveRecovery.delay,
    this._clock = DateTime.now,
  }) {
    _failureSub = engine.failures.listen((_) => _handleFailure());
    if (tickInterval != null) _timer = Timer.periodic(tickInterval, (_) => tick());
  }

  final PlaybackEngine engine;
  final Duration retryDelay;
  final DateTime Function() _clock;

  String? source;
  bool isLive = false;
  double position = 0;
  double duration = 0;
  bool paused = false;
  double speed = 1;
  List<Track> tracks = const [];

  /// "4K", "FHD", "HD", "SD" for the picture being decoded; null until the size is known (or for audio only).
  String? quality;
  bool buffering = false;
  bool atEnd = false;

  /// True once the stream failed for good (a live stream only after its retries); [failure] is the engine's reason.
  bool failed = false;
  String? failure;
  int? sleepMinutesLeft;

  /// (position, duration): about every 20 s while a movie plays, when the item is replaced and on [close].
  void Function(double position, double duration)? onSaveProgress;

  /// A movie/episode reached its end (true) or left it again (false).
  void Function(bool atEnd)? onEndChanged;

  /// The sleep timer ran out.
  VoidCallback? onSleep;

  final _recovery = LiveRecovery();
  final _end = EndOfMedia();
  final _pauseClock = PauseClock();
  final _sleep = SleepTimer();
  late final StreamSubscription<String> _failureSub;
  Timer? _timer;
  Timer? _retryTimer;
  int _ticks = 0;
  bool _closed = false;
  bool _retryPending = false;
  int _generation = 0; // bumped on every explicit load: a stale retry timer cannot reload an old item

  static const _saveEveryTicks = 80; // 20 s at 4 ticks a second
  static const _tracksEveryTicks = 16;

  bool get closed => _closed;

  // Loading

  /// Starts [src] (the first one, or the next channel/episode: the old position is saved first).
  void play(String src, {required bool live, double start = 0, double speed = 1}) {
    if (_closed) return;
    _saveIfLoaded();
    _generation++;
    _retryTimer?.cancel();
    source = src;
    isLive = live;
    _recovery.reset();
    _end.newFile();
    _pauseClock.reset();
    position = 0;
    duration = 0;
    atEnd = false;
    failed = false;
    failure = null;
    _retryPending = false;
    paused = false;
    buffering = true;
    tracks = const [];
    setSpeed(speed); // 1, or what the user kept for this series
    engine.load(src, start: start);
    notifyListeners();
  }

  /// The failure card's Retry: a live stream starts again at the live edge, a movie at the position it had.
  void retry() {
    final src = source;
    if (_closed || src == null) return;
    _generation++;
    _retryTimer?.cancel();
    _recovery.reset();
    _retryPending = false;
    failed = false;
    failure = null;
    buffering = true;
    final start = isLive ? 0.0 : position;
    position = 0;
    engine.load(src, start: start);
    notifyListeners();
  }

  void _handleFailure() {
    if (_closed || _retryPending || failed) return;
    if (isLive && _recovery.failed()) {
      _retryPending = true;
      final gen = _generation;
      _retryTimer = Timer(retryDelay, () {
        final src = source;
        if (_closed || _generation != gen || src == null) return;
        _retryPending = false;
        position = 0;
        _recovery.reloaded();
        engine.load(src);
      });
    } else {
      failed = true;
      failure = engine.lastError;
      buffering = false;
      notifyListeners();
    }
  }

  // Transport

  void togglePause([DateTime? now]) => setPlaying(paused, now);

  /// `true` plays, `false` pauses. A live stream that sat paused long enough is reloaded instead of resumed from its old cache.
  void setPlaying(bool play, [DateTime? now]) {
    now ??= _clock();
    if (play) {
      if (atEnd && !isLive) {
        replay();
        return;
      }
      final src = source;
      if (_pauseClock.resumed(now, isLive: isLive) && src != null) {
        _generation++;
        engine.load(src);
      }
      engine.setPaused(false);
    } else {
      _pauseClock.paused(now);
      engine.setPaused(true);
    }
    paused = !play;
    notifyListeners();
  }

  /// From the start again after the end (the engine stays on the last frame).
  void replay() {
    engine.seekTo(0);
    engine.setPaused(false);
    position = 0;
    paused = false;
    notifyListeners();
  }

  /// The position shown moves at once (the next tick would make a dragged bar jump back).
  void seekBy(double s) {
    engine.seekBy(s);
    position = _clampPosition(position + s);
    notifyListeners();
  }

  void seekTo(double s) {
    engine.seekTo(s);
    position = _clampPosition(s);
    notifyListeners();
  }

  double _clampPosition(double p) => p.clamp(0.0, duration > 0 ? duration : double.infinity);

  /// Clamped to 0.25...4 and rounded to 0.05, set at once.
  void setSpeed(double s) {
    speed = PlaybackSpeed.normalized(s);
    engine.setSpeed(speed);
    notifyListeners();
  }

  /// 0 turns the timer off.
  void setSleep(int minutes, [DateTime? now]) {
    now ??= _clock();
    _sleep.set(minutes, now);
    sleepMinutesLeft = _sleep.remainingMinutes(now);
    notifyListeners();
  }

  // Polling

  void tick([DateTime? now]) {
    if (_closed) return;
    now ??= _clock();
    if (_sleep.expired(now)) {
      _sleep.cancel();
      sleepMinutesLeft = null;
      notifyListeners();
      onSleep?.call();
      return;
    }
    sleepMinutesLeft = _sleep.remainingMinutes(now);
    position = engine.position;
    duration = engine.duration;
    final eof = engine.atEof;
    if (isLive) {
      _recovery.observe(position);
      // With keep-open a dropped live stream just stops at EOF (no failure event): treat it as a failure.
      if (eof && !failed) _handleFailure();
    } else {
      final ended = _end.observe(atEof: eof, position: position, duration: duration);
      if (ended != null) {
        atEnd = ended;
        onEndChanged?.call(ended);
      }
    }
    paused = engine.paused;
    speed = engine.speed;
    quality = videoQualityLabel(engine.videoWidth, engine.videoHeight);   // an adaptive stream can change size while it plays
    buffering = !failed && !paused && !atEnd && (engine.buffering || (position == 0 && duration == 0));
    _ticks++;
    if (tracks.isEmpty || _ticks % _tracksEveryTicks == 0) tracks = engine.tracks;
    if (_ticks % _saveEveryTicks == 0) _saveIfLoaded();
    notifyListeners();
  }

  /// A position of 0 means "nothing played yet" (still loading or the load failed): saving it would erase the resume point.
  void _saveIfLoaded() {
    if (!isLive && position > 0) onSaveProgress?.call(position, duration);
  }

  /// Saves now (the app goes to the background, where it may be killed without notice).
  void saveNow() => _saveIfLoaded();

  /// Saves the position and stops the engine. The controller is dead afterwards.
  void close() {
    if (_closed) return;
    _closed = true;
    _saveIfLoaded();
    _timer?.cancel();
    _retryTimer?.cancel();
    _failureSub.cancel();
    engine.dispose();
  }

  @override
  void dispose() {
    close();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_closed) super.notifyListeners();
  }
}
