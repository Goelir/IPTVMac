/// Where the intro and the credits of a series are, as the user marked them once (providers do not publish this). The marks belong to
/// the series, so every episode of it offers the skip buttons at the same places. Port of IPTVCore/SkipMarks.swift.
class SkipMarks {
  const SkipMarks({this.introStart, this.introEnd, this.creditsLen});

  /// Seconds from the start of an episode where the intro begins (null: at the very start) and where the real content begins.
  final double? introStart, introEnd;

  /// Seconds before the end of an episode where the credits begin (the length of the credits, so it also fits other lengths).
  final double? creditsLen;

  bool get isEmpty => introStart == null && introEnd == null && creditsLen == null;

  @override
  bool operator ==(Object other) => other is SkipMarks && other.introStart == introStart && other.introEnd == introEnd && other.creditsLen == creditsLen;

  @override
  int get hashCode => Object.hash(introStart, introEnd, creditsLen);

  @override
  String toString() => 'SkipMarks($introStart, $introEnd, $creditsLen)';
}

/// What the player offers at one moment.
sealed class SkipOffer {
  const SkipOffer();
}

/// "Skip intro": seek to [to].
final class SkipIntro extends SkipOffer {
  const SkipIntro(this.to);
  final double to;

  @override
  bool operator ==(Object other) => other is SkipIntro && other.to == to;

  @override
  int get hashCode => to.hashCode;
}

/// "Skip credits": go to the next episode, or to the end when there is none.
final class SkipCredits extends SkipOffer {
  const SkipCredits();

  @override
  bool operator ==(Object other) => other is SkipCredits;

  @override
  int get hashCode => 7;
}

abstract final class SkipLogic {
  /// The button to show at [position], if any. [duration] is 0 while it is unknown.
  static SkipOffer? offer(SkipMarks m, {required double position, required double duration}) {
    if (!position.isFinite || position < 0) return null;
    final end = m.introEnd;
    if (end != null && end > 1) {
      final start = m.introStart ?? 0;
      if (position >= start && position < end - 1 && (duration <= 0 || end < duration * 0.6)) return SkipIntro(end);
    }
    final len = m.creditsLen;
    if (len != null && len >= 5 && duration > 0 && len <= duration * 0.5 && position >= duration - len && position < duration - 2) {
      return const SkipCredits();
    }
    return null;
  }

  /// Marking "the intro starts here": in the first half. An intro end that is no longer after it is dropped.
  static SkipMarks? markIntroStart(SkipMarks m, {required double position, required double duration}) {
    if (position < 0 || (duration > 0 && position >= duration * 0.5)) return null;
    final start = position < 1 ? null : position;
    final end = m.introEnd;
    return SkipMarks(introStart: start, introEnd: end != null && end <= position + 2 ? null : end, creditsLen: m.creditsLen);
  }

  /// Marking "the intro ends here": after its start, and not past 60 % of the episode.
  static SkipMarks? markIntroEnd(SkipMarks m, {required double position, required double duration}) {
    if (position <= (m.introStart ?? 0) + 2 || (duration > 0 && position >= duration * 0.6)) return null;
    return SkipMarks(introStart: m.introStart, introEnd: position, creditsLen: m.creditsLen);
  }

  /// Marking "the credits start here": at least 5 seconds before the end, and not in the first half.
  static SkipMarks? markCredits(SkipMarks m, {required double position, required double duration}) {
    if (duration <= 0 || position < duration * 0.5 || duration - position < 5) return null;
    return SkipMarks(introStart: m.introStart, introEnd: m.introEnd, creditsLen: duration - position);
  }
}
