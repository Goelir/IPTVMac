import 'dart:io' show Platform;

/// How the video fills the window; the name is the stored preference ("videoScale"). Mapped to the widget's BoxFit by the screen.
enum VideoScale {
  fit,
  fill,
  stretch;

  VideoScale get next => this == fit ? fill : (this == fill ? stretch : fit);
  static VideoScale parse(String? s) => values.firstWhere((v) => v.name == s, orElse: () => fit);
}

/// How much the player reads ahead of the playback position; the name is the stored preference ("bufferSize").
enum BufferSize {
  small(16 << 20, 8),
  normal(64 << 20, 20),
  large(256 << 20, 60);

  const BufferSize(this.maxBytes, this.readaheadSecs);

  /// mpv `demuxer-max-bytes` and `demuxer-readahead-secs`.
  final int maxBytes;
  final int readaheadSecs;
  static BufferSize parse(String? s) => values.firstWhere((v) => v.name == s, orElse: () => normal);
}

/// Options of the libmpv instance. Streams, playlists and subtitles come from a third party: the Xtream password is in the URL, so
/// HTTPS is verified, and everything that can run code or read the disk is off. The CA file is set by the engine (ca_bundle.dart): Android keeps
/// its roots as one file per certificate in a directory, not as a bundle, and mpv's TLS library cannot read that.
abstract final class EngineOptions {
  /// `hwdec` list: the first one that works wins, so a device without MediaCodec falls back to mpv's safe auto list.
  /// MediaCodec exists only on Android; Windows takes mpv's safe auto list (Direct3D 11 decoding, no copy back where it can).
  static String get hwdec => Platform.isAndroid ? 'mediacodec-copy,auto-safe' : 'auto-safe';

  static Map<String, String> hardened({bool tlsVerify = true}) => {
        'network-timeout': '15',
        'stream-lavf-o': 'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5',
        'tls-verify': tlsVerify ? 'yes' : 'no',
        'embeddedfonts': 'no',
        'ytdl': 'no',
        'load-scripts': 'no',
        'config': 'no',
      };
}
