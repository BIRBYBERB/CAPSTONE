import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/player_pool.dart';
import '../audio/tone_synth.dart';

class PianoPage extends StatefulWidget {
  const PianoPage({super.key});

  @override
  State<PianoPage> createState() => _PianoPageState();
}

class _PianoPageState extends State<PianoPage> {
  final PlayerPool _pool = PlayerPool();

  // White keys C4..C5, plus sharps mapped by position.
  static const List<String> _whiteNoteNames = [
    'C4', 'D4', 'E4', 'F4', 'G4', 'A4', 'B4', 'C5'
  ];
  static const List<double> _whiteFreqs = [
    261.63, 293.66, 329.63, 349.23, 392.00, 440.00, 493.88, 523.25
  ];
  // Black key: (index of white key it sits after, name, frequency)
  static const List<_BlackKeySpec> _blackKeys = [
    _BlackKeySpec(0, 'C#4', 277.18),
    _BlackKeySpec(1, 'D#4', 311.13),
    _BlackKeySpec(3, 'F#4', 369.99),
    _BlackKeySpec(4, 'G#4', 415.30),
    _BlackKeySpec(5, 'A#4', 466.16),
  ];

  void _playFreq(double freq) {
    final wav = ToneSynth.generate(frequency: freq, plucked: false);
    _pool.play(wav);
  }

  @override
  void dispose() {
    _pool.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Piano')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double keyboardWidth = math.min(constraints.maxWidth, 560);
              final double whiteKeyWidth = keyboardWidth / _whiteFreqs.length;
              final double keyboardHeight = 320;

              return SizedBox(
                width: keyboardWidth,
                height: keyboardHeight,
                child: Stack(
                  children: [
                    // White keys
                    Row(
                      children: List.generate(_whiteFreqs.length, (i) {
                        return GestureDetector(
                          onTapDown: (_) => _playFreq(_whiteFreqs[i]),
                          child: Container(
                            width: whiteKeyWidth,
                            height: keyboardHeight,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(6)),
                            ),
                            alignment: Alignment.bottomCenter,
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              _whiteNoteNames[i],
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ),
                        );
                      }),
                    ),
                    // Black keys, overlaid
                    ..._blackKeys.map((spec) {
                      final double left = whiteKeyWidth * (spec.afterWhiteIndex + 1) -
                          (whiteKeyWidth * 0.3);
                      return Positioned(
                        left: left,
                        top: 0,
                        child: GestureDetector(
                          onTapDown: (_) => _playFreq(spec.freq),
                          child: Container(
                            width: whiteKeyWidth * 0.6,
                            height: keyboardHeight * 0.6,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(4)),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BlackKeySpec {
  final int afterWhiteIndex;
  final String name;
  final double freq;
  const _BlackKeySpec(this.afterWhiteIndex, this.name, this.freq);
}