import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';

import 'ca_bundle.dart';
import 'engine.dart';
import 'player_options.dart';
import 'track_label.dart';

/// libmpv through media_kit. Needs `MediaKit.ensureInitialized()` before the first one is made (the app's main does it).
class MediaKitEngine implements PlaybackEngine {
  MediaKitEngine({String? hwdec, bool tlsVerify = true, String? subLang, String? audioLang}) {
    _player = mk.Player(configuration: const mk.PlayerConfiguration(title: 'IPTVMac'));
    _video = VideoController(_player, configuration: VideoControllerConfiguration(hwdec: hwdec ?? EngineOptions.hwdec));
    _native = _player.platform as mk.NativePlayer;
    _ready = _applyOptions(tlsVerify, subLang, audioLang);
    _subs = [
      _player.stream.playing.listen((p) => _paused = !p),
      _player.stream.error.listen(_onError),
      _player.stream.track.listen((_) => _readSelection()),
      _player.stream.tracks.listen((_) => _readSelection()),
    ];
  }

  late final mk.Player _player;
  late final VideoController _video;
  late final mk.NativePlayer _native;
  late final Future<void> _ready;           // the options are in before the first file opens
  late final List<StreamSubscription<Object?>> _subs;
  final _failures = StreamController<String>.broadcast();
  final _subtitleScale = ValueNotifier<double>(1);
  bool _paused = false;
  bool _disposed = false;
  String? _lastError;
  int _aid = 0;
  int _sid = 0;

  Future<void> _applyOptions(bool tlsVerify, String? subLang, String? audioLang) async {
    final options = {
      ...EngineOptions.hardened(tlsVerify: tlsVerify),
      if (subLang != null && subLang.isNotEmpty) 'slang': subLang,
      if (audioLang != null && audioLang.isNotEmpty) 'alang': audioLang,
    };
    for (final e in options.entries) {
      await _set(e.key, e.value);
    }
    if (tlsVerify) {
      try {
        await _set('tls-ca-file', await CaBundle.path());
      } catch (_) {} // no asset (a test): mpv falls back to its own store
    }
  }

  Future<void> _set(String name, String value) async {
    if (_disposed) return;
    try {
      await _native.setProperty(name, value);
    } catch (_) {} // a pre-init-only option or a disposed player: nothing to do about it
  }

  /// An error log line is only a failure when mpv gave up on the file (it went idle); the ffmpeg reconnect logic logs and recovers.
  Future<void> _onError(String reason) async {
    _lastError = reason;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (_disposed) return;
    try {
      if (await _native.getProperty('idle-active') == 'yes' && !_failures.isClosed) _failures.add(reason);
    } catch (_) {}
  }

  Future<void> _readSelection() async {
    if (_disposed) return;
    try {
      _aid = int.tryParse(await _native.getProperty('aid')) ?? 0;
      _sid = int.tryParse(await _native.getProperty('sid')) ?? 0;
    } catch (_) {}
  }

  @override
  Stream<String> get failures => _failures.stream;
  @override
  String? get lastError => _lastError;
  @override
  double get position => _player.state.position.inMicroseconds / 1e6;
  @override
  double get duration => _player.state.duration.inMicroseconds / 1e6;
  @override
  bool get paused => _paused;
  @override
  bool get buffering => _player.state.buffering;
  @override
  bool get atEof => _player.state.completed;
  @override
  double get speed => _player.state.rate;
  @override
  double get aspect {
    final w = _player.state.width, h = _player.state.height;
    return w != null && h != null && w > 0 && h > 0 ? w / h : 0;
  }

  @override
  int get videoWidth => _player.state.width ?? 0;
  @override
  int get videoHeight => _player.state.height ?? 0;

  @override
  List<Track> get tracks => [
        for (final t in _player.state.tracks.audio)
          if (int.tryParse(t.id) case final id?) Track(id: id, type: 'audio', lang: t.language, title: t.title, selected: id == _aid),
        for (final t in _player.state.tracks.subtitle)
          if (int.tryParse(t.id) case final id?) Track(id: id, type: 'sub', lang: t.language, title: t.title, selected: id == _sid),
      ];

  @override
  void load(String source, {double start = 0}) {
    _lastError = null;
    _paused = false;
    _aid = 0;
    _sid = 0;
    final from = start > 1 ? Duration(seconds: start.toInt()) : null;
    unawaited(_ready.then((_) => _disposed ? null : _player.open(mk.Media(source, start: from))).catchError((Object _) {}));
  }

  @override
  void setPaused(bool paused) {
    _paused = paused;
    unawaited((paused ? _player.pause() : _player.play()).catchError((Object _) {}));
  }

  @override
  void seekTo(double seconds) => unawaited(_player.seek(Duration(milliseconds: (seconds * 1000).round())).catchError((Object _) {}));

  @override
  void seekBy(double seconds) => seekTo(position + seconds);

  @override
  void setSpeed(double speed) => unawaited(_player.setRate(speed).catchError((Object _) {}));

  @override
  void selectSubtitle(int id) {
    _sid = id;
    unawaited(_player.setSubtitleTrack(id == 0 ? mk.SubtitleTrack.no() : mk.SubtitleTrack('$id', null, null)).catchError((Object _) {}));
  }

  @override
  void selectAudio(int id) {
    _aid = id;
    unawaited(_player.setAudioTrack(mk.AudioTrack('$id', null, null)).catchError((Object _) {}));
  }

  @override
  void addSubtitle(String path) =>
      unawaited(_player.setSubtitleTrack(mk.SubtitleTrack.uri(Uri.file(path).toString())).then((_) => _readSelection()).catchError((Object _) {}));

  @override
  void setSubtitleStyle({required double scale, required double delay}) {
    _subtitleScale.value = scale;
    unawaited(_set('sub-delay', delay.toString()));
  }

  @override
  void setVolume(double volume) => unawaited(_player.setVolume(volume * 100).catchError((Object _) {}));

  @override
  void setBuffer(int maxBytes, int readaheadSecs) {
    unawaited(_set('demuxer-max-bytes', '$maxBytes'));
    unawaited(_set('demuxer-readahead-secs', '$readaheadSecs'));
  }

  @override
  Widget buildVideo(BoxFit fit) => ValueListenableBuilder<double>(
        valueListenable: _subtitleScale,
        builder: (_, scale, _) => Video(
          controller: _video,
          fit: fit,
          controls: NoVideoControls,
          fill: Colors.black,
          pauseUponEnteringBackgroundMode: false, // the default pauses the sound when the screen turns off; the media session decides what plays in the background
          subtitleViewConfiguration: SubtitleViewConfiguration(
            style: TextStyle(fontSize: 32 * scale, color: Colors.white, backgroundColor: const Color(0xAA000000), height: 1.3),
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 56),
          ),
        ),
      );

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final s in _subs) {
      s.cancel();
    }
    _failures.close();
    unawaited(_player.dispose());
  }
}
