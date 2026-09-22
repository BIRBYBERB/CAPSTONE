/// Standard rhythmic note values. `beats` is expressed relative to a
/// quarter note = 1 beat, which is the unit the tempo (BPM) is defined in.
enum NoteDuration { whole, half, quarter, eighth, sixteenth }

extension NoteDurationX on NoteDuration {
  double get beats {
    switch (this) {
      case NoteDuration.whole:
        return 4;
      case NoteDuration.half:
        return 2;
      case NoteDuration.quarter:
        return 1;
      case NoteDuration.eighth:
        return 0.5;
      case NoteDuration.sixteenth:
        return 0.25;
    }
  }

  String get label {
    switch (this) {
      case NoteDuration.whole:
        return 'Whole';
      case NoteDuration.half:
        return 'Half';
      case NoteDuration.quarter:
        return 'Quarter';
      case NoteDuration.eighth:
        return 'Eighth';
      case NoteDuration.sixteenth:
        return 'Sixteenth';
    }
  }

  /// Standard Unicode music notation glyphs.
  String get symbol {
    switch (this) {
      case NoteDuration.whole:
        return '\u{1D15D}'; // 𝅝
      case NoteDuration.half:
        return '\u{1D15E}'; // 𝅗𝅥
      case NoteDuration.quarter:
        return '\u2669'; // ♩
      case NoteDuration.eighth:
        return '\u266A'; // ♪
      case NoteDuration.sixteenth:
        return '\u{1D161}'; // 𝅘𝅥𝅯
    }
  }
}