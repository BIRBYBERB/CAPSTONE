import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/player_pool.dart';
import '../audio/tone_synth.dart';

/// A simplified visual: vertical plucked "strings" fanned out across the
/// screen, tuned to a diatonic scale across two octaves. Drag a finger
/// across the strings, or tap one, to pluck it.
class SasandoPage extends StatefulWidget {
  const SasandoPage({super.key});

  @override
  State<SasandoPage> createState() => _SasandoPageState();
}

class _SasandoPageState extends State<SasandoPage> {
  final PlayerPool _pool = PlayerPool();

  // Two octaves of a diatonic (major) scale starting at G3, a fairly
  // typical open-string spread for a sasando.
  late final List<double> _stringFreqs = _buildScale();
  int? _lastPluckedIndex;

  List<double> _buildScale() {
    const double g3 = 196.00;
    const List<double> steps = [0, 2, 4, 5, 7, 9, 11, 12]; // major scale, semitones
    final List<double> freqs = [];
    for (int octave = 0; octave < 2; octave++) {
      for (final s in steps) {
        final semitone = s + (octave * 12);
        freqs.add(g3 * math.pow(2, semitone / 12));
      }
    }
    return freqs; // 16 strings
  }

  void _pluck(int index) {
    if (index < 0 || index >= _stringFreqs.length) return;
    final wav = ToneSynth.generate(
      frequency: _stringFreqs[index],
      durationSeconds: 2.0,
      plucked: true,
    );
    _pool.play(wav);
    setState(() => _lastPluckedIndex = index);
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted && _lastPluckedIndex == index) {
        setState(() => _lastPluckedIndex = null);
      }
    });
  }

  @override
  void dispose() {
    _pool.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sasando')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Tap or drag across the strings to pluck them',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final int stringCount = _stringFreqs.length;
                  final double width = constraints.maxWidth;
                  final double stringSpacing = width / stringCount;

                  return GestureDetector(
                    onPanStart: (details) => _pluckFromPosition(
                        details.localPosition.dx, stringSpacing, stringCount),
                    onPanUpdate: (details) => _pluckFromPosition(
                        details.localPosition.dx, stringSpacing, stringCount),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.brown.shade100, Colors.brown.shade200],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: List.generate(stringCount, (i) {
                          final bool plucked = _lastPluckedIndex == i;
                          return Expanded(
                            child: GestureDetector(
                              onTapDown: (_) => _pluck(i),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                alignment: Alignment.center,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 90),
                                  width: plucked ? 4 : 2,
                                  color: plucked
                                      ? Colors.deepPurple
                                      : Colors.brown.shade700,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pluckFromPosition(double dx, double spacing, int stringCount) {
    final int index = (dx / spacing).floor().clamp(0, stringCount - 1);
    if (index != _lastPluckedIndex) {
      _pluck(index);
    }
  }
}