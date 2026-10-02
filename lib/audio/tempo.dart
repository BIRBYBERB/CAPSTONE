/// Default beats per minute used to translate note durations (in beats,
/// where a quarter note = 1 beat) into real playback time.
const int kBeatsPerMinute = 96;

double beatsToMilliseconds(double beats, {int bpm = kBeatsPerMinute}) {
  if (bpm <= 0) {
    throw ArgumentError.value(bpm, 'bpm', 'Must be greater than zero');
  }
  return beats * (60000 / bpm);
}
