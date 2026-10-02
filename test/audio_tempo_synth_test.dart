import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:projectcapstone/audio/tempo.dart';
import 'package:projectcapstone/audio/tone_synth.dart';

void main() {
  group('beatsToMilliseconds', () {
    test('uses the default tempo or the supplied tempo', () {
      expect(beatsToMilliseconds(1), 625);
      expect(beatsToMilliseconds(2, bpm: 120), 1000);
    });

    test('rejects a non-positive tempo', () {
      expect(() => beatsToMilliseconds(1, bpm: 0), throwsArgumentError);
    });
  });

  test('piano tone sustains for the note and fades out after its duration', () {
    const durationSeconds = 1.0;
    const sampleRate = 44100;
    const releaseSeconds = 0.12;
    final wav = ToneSynth.generate(
      frequency: 440,
      durationSeconds: durationSeconds,
      sampleRate: sampleRate,
    );
    final data = ByteData.sublistView(wav);

    expect(
      wav.length,
      44 + (sampleRate * (durationSeconds + releaseSeconds)).toInt() * 2,
    );
    expect(
      _rms(data, sampleRate, 0.7, 0.1),
      greaterThan(_rms(data, sampleRate, 0.2, 0.1) * 0.8),
    );
    expect(_rms(data, sampleRate, 1.115, 0.004), lessThan(200));
  });

  test('short notes include a separate smooth release tail', () {
    const durationSeconds = 0.15625;
    const sampleRate = 44100;
    final wav = ToneSynth.generate(
      frequency: 440,
      durationSeconds: durationSeconds,
      sampleRate: sampleRate,
    );

    expect(
      wav.length,
      44 + (sampleRate * (durationSeconds + 0.12)).toInt() * 2,
    );
  });
}

double _rms(ByteData data, int sampleRate, double start, double length) {
  final int firstSample = (start * sampleRate).round();
  final int sampleCount = (length * sampleRate).round();
  double sumSquares = 0;

  for (int i = 0; i < sampleCount; i++) {
    final int sample = data.getInt16(44 + (firstSample + i) * 2, Endian.little);
    sumSquares += sample * sample;
  }

  return math.sqrt(sumSquares / sampleCount);
}
