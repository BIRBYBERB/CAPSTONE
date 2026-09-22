/// Beats per minute used to translate note durations (in beats, where a
/// quarter note = 1 beat) into real playback time. One fixed tempo for
/// the whole app for now; could become user-adjustable later.
const int kBeatsPerMinute = 96;

double beatsToMilliseconds(double beats) => beats * (60000 / kBeatsPerMinute);