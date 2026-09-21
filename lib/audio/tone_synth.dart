import 'dart:math' as math;
import 'dart:typed_data';

/// Builds a tiny 16-bit PCM WAV in memory for any frequency/envelope
/// combo, so no external audio asset files are needed.
class ToneSynth {
  static final Map<String, Uint8List> _cache = {};

  static Uint8List generate({
    required double frequency,
    double durationSeconds = 1.6,
    int sampleRate = 44100,
    bool plucked = false,
  }) {
    final String key =
        '${frequency.toStringAsFixed(2)}_${durationSeconds}_$plucked';
    final cached = _cache[key];
    if (cached != null) return cached;

    final int numSamples = (sampleRate * durationSeconds).toInt();
    final Int16List samples = Int16List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      double envelope;

      if (plucked) {
        // Sasando: sharp pluck, fast exponential decay (like a plucked string).
        envelope = math.exp(-4.2 * t);
      } else {
        // Piano: quick attack, slower decay, gentle sustain tail.
        const double attack = 0.008;
        if (t < attack) {
          envelope = t / attack;
        } else {
          envelope = math.exp(-1.8 * (t - attack));
        }
      }

      // A few harmonics blended in for a fuller, less "beepy" timbre.
      double sample = math.sin(2 * math.pi * frequency * t) * 0.55 +
          math.sin(2 * math.pi * frequency * 2 * t) * 0.22 +
          math.sin(2 * math.pi * frequency * 3 * t) * 0.13 +
          math.sin(2 * math.pi * frequency * 4 * t) * 0.06;

      sample *= envelope;
      final int clamped = (sample.clamp(-1.0, 1.0) * 32000).toInt();
      samples[i] = clamped;
    }

    final Uint8List wav = _wrapAsWav(samples, sampleRate);
    _cache[key] = wav;
    return wav;
  }

  static Uint8List _wrapAsWav(Int16List samples, int sampleRate) {
    final int dataLength = samples.length * 2;
    final int byteRate = sampleRate * 2;
    final Uint8List bytes = Uint8List(44 + dataLength);
    final ByteData bd = ByteData.view(bytes.buffer);

    void writeString(int offset, String s) {
      for (int i = 0; i < s.length; i++) {
        bytes[offset + i] = s.codeUnitAt(i);
      }
    }

    writeString(0, 'RIFF');
    bd.setUint32(4, 36 + dataLength, Endian.little);
    writeString(8, 'WAVE');
    writeString(12, 'fmt ');
    bd.setUint32(16, 16, Endian.little); // PCM header size
    bd.setUint16(20, 1, Endian.little); // PCM format
    bd.setUint16(22, 1, Endian.little); // mono
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, byteRate, Endian.little);
    bd.setUint16(32, 2, Endian.little); // block align
    bd.setUint16(34, 16, Endian.little); // bits per sample
    writeString(36, 'data');
    bd.setUint32(40, dataLength, Endian.little);

    for (int i = 0; i < samples.length; i++) {
      bd.setInt16(44 + i * 2, samples[i], Endian.little);
    }
    return bytes;
  }
}