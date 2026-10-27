import 'dart:async';

/// What the lock screen, the notification and Bluetooth/headset buttons show and can do.
class NowPlaying {
  const NowPlaying({
    required this.title,
    this.subtitle,
    required this.isLive,
    required this.position,
    required this.duration,
    required this.speed,
    required this.paused,
    this.canNext = false,
    this.canPrevious = false,
    this.buffering = false,
  });

  final String title;
  final String? subtitle;
  final bool isLive;
  final double position;
  final double duration;
  final double speed;
  final bool paused;
  final bool canNext;
  final bool canPrevious;
  final bool buffering;
}

/// What the system can ask the player to do (notification buttons, headset, other apps).
class PlayerCommands {
  const PlayerCommands({
    required this.play,
    required this.pause,
    required this.skip,
    required this.seek,
    required this.next,
    required this.previous,
    required this.stop,
    required this.isPlaying,
    this.seekStep = 10,
  });

  final void Function() play;
  final void Function() pause;
  final void Function(double seconds) skip;
  final void Function(double seconds) seek;
  final void Function() next;
  final void Function() previous;
  final void Function() stop;
  final bool Function() isPlaying;

  /// Seconds the notification's rewind and fast-forward buttons skip.
  final int seekStep;
}

/// The player's seat in the operating system: screen orientation and system bars, wake lock, brightness and volume, Picture in
/// Picture, and the media session (notification, audio focus). The Android implementation is in android_player_system.dart; this
/// base class does nothing, which is also what the tests and other platforms get.
class PlayerSystem {
  /// Landscape on phones, immersive bars, screen awake. Undone by [exit].
  Future<void> enter({required bool lockLandscape}) async {}
  Future<void> exit() async {}

  /// The rotate button: upright (true) or landscape (false), until the player closes.
  Future<void> setPortrait(bool portrait) async {}
  void setAwake(bool awake) {}

  /// 0...1; null when the system cannot tell.
  Future<double?> brightness() async => null;
  void setBrightness(double v) {}
  void restoreBrightness() {}
  Future<double?> volume() async => null;
  void setVolume(double v) {}

  /// The window fills the screen (a desktop; a phone and a TV already do).
  Future<void> setFullscreen(bool on) async {}

  Future<bool> isPipSupported() async => false;

  /// Enters Picture in Picture; false when the system refused.
  Future<bool> enterPip({required double aspect, required bool playing}) async => false;

  /// Tells the system the state PiP needs (play/pause button, auto-enter when the user leaves the app while playing).
  void updatePip({required double aspect, required bool playing, required bool autoEnter}) {}
  final pipChanges = StreamController<bool>.broadcast();

  /// Play/pause pressed in the PiP window.
  final pipActions = StreamController<void>.broadcast();

  /// Starts the media session and takes audio focus; [commands] is what the system may ask for.
  Future<void> activate(PlayerCommands commands) async {}
  void updateNowPlaying(NowPlaying n) {}

  /// The user pressed play/pause themselves: that wins over an automatic resume after a call.
  void userChose() {}
  Future<void> deactivate() async {}
}
