import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iptvmac/core/remote_image.dart';

/// Screenshots only: lets artwork load from the local demo provider (127.0.0.1 / 10.0.2.2), which [safeImageUrl] rightly refuses.
/// Compiled in only with `--dart-define=DEMO_IMAGES=true`, and only honoured in debug builds.
const _demoImages = bool.fromEnvironment('DEMO_IMAGES');

/// The only way a provider-supplied logo or poster address reaches the network (the same rule as the Apple apps).
Uri? artUri(String? raw) {
  final safe = safeImageUrl(raw);
  if (safe != null || !(kDebugMode && _demoImages)) return safe;
  final u = Uri.tryParse(raw?.trim() ?? '');
  return u != null && (u.scheme == 'http' || u.scheme == 'https') && u.host.isNotEmpty ? u : null;
}

/// An image that fades in when it has loaded; [placeholder] shows before that, on an error and when there is no address.
class ArtworkImage extends StatelessWidget {
  const ArtworkImage({super.key, required this.url, required this.placeholder, this.maxPixel = 480, this.fit = BoxFit.cover});

  final Uri? url;
  final Widget placeholder;
  final int maxPixel;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null) return placeholder;
    return CachedNetworkImage(
      imageUrl: u.toString(),
      fit: fit,
      memCacheWidth: maxPixel,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => placeholder,
    );
  }
}

/// What stands in for a missing logo or poster: the first letters on a tile whose hue comes from the name (always the same one).
class Monogram extends StatelessWidget {
  const Monogram({super.key, required this.name, this.fontSize = 18});

  final String name;
  final double fontSize;

  static String initials(String name) {
    final words = name.split(RegExp(r'[^\p{L}\p{N}]+', unicode: true)).where((w) => w.isNotEmpty);
    final letters = words.take(2).map((w) => String.fromCharCode(w.runes.first)).join();
    final t = name.trim();
    return (letters.isEmpty ? (t.isEmpty ? '' : String.fromCharCode(t.runes.first)) : letters).toUpperCase();
  }

  /// Teal to broadcast blue, quiet enough for a wall of them; stable across launches (djb2 like the Apple apps).
  static double hue(String name) {
    var h = 5381;
    for (final u in name.runes) {
      h = (h * 33 + u) & 0xFFFFFFFF;
    }
    return 0.50 + 0.18 * (h % 1000) / 1000;
  }

  @override
  Widget build(BuildContext context) {
    final h = hue(name) * 360, h2 = (hue(name) + 0.03) % 1 * 360;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [HSVColor.fromAHSV(1, h, 0.42, 0.66).toColor(), HSVColor.fromAHSV(1, h2, 0.55, 0.40).toColor()],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(initials(name), maxLines: 1, style: TextStyle(color: Colors.white, fontSize: min(fontSize, 40), fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }
}
