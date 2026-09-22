import 'note_duration.dart';

/// A single played note, tagged with the rhythmic value the user picked
/// for it (whole, half, quarter, etc.), so the sheet can be laid out and
/// played back musically rather than by real-time recording gaps.
class NoteEvent {
  final String name;
  final double frequency;
  final NoteDuration duration;

  NoteEvent({
    required this.name,
    required this.frequency,
    required this.duration,
  });
}