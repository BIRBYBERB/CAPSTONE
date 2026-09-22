import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../audio/note_duration.dart';
import '../audio/note_event.dart';
import '../audio/player_pool.dart';
import '../audio/tempo.dart';
import '../audio/tone_synth.dart';
import '../widgets/duration_selector.dart';
import '../widgets/music_sheet.dart';

class PianoPage extends StatefulWidget {
  const PianoPage({super.key});

  @override
  State<PianoPage> createState() => _PianoPageState();
}

class _PianoPageState extends State<PianoPage> {
  final PlayerPool _pool = PlayerPool();
  final List<NoteEvent> _notes = [];
  NoteDuration _selectedDuration = NoteDuration.quarter;
  bool _isPlaying = false;
  int? _playingIndex;

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

  void _playNote(String name, double freq) {
    final double ms = beatsToMilliseconds(_selectedDuration.beats);
    final wav = ToneSynth.generate(
      frequency: freq,
      durationSeconds: ms / 1000,
      plucked: false,
    );
    _pool.play(wav);

    setState(() {
      _notes.add(NoteEvent(name: name, frequency: freq, duration: _selectedDuration));
    });
  }

  void _clearSheet() {
    setState(() => _notes.clear());
  }

  Future<void> _playSheet() async {
    if (_notes.isEmpty || _isPlaying) return;
    setState(() => _isPlaying = true);

    for (int i = 0; i < _notes.length; i++) {
      if (!_isPlaying || !mounted) break;
      final note = _notes[i];
      final double ms = beatsToMilliseconds(note.duration.beats);

      final wav = ToneSynth.generate(
        frequency: note.frequency,
        durationSeconds: ms / 1000,
        plucked: false,
      );
      _pool.play(wav);
      setState(() => _playingIndex = i);

      await Future.delayed(Duration(milliseconds: ms.round()));
    }

    if (mounted) {
      setState(() {
        _isPlaying = false;
        _playingIndex = null;
      });
    }
  }

  void _stopPlayback() {
    setState(() => _isPlaying = false);
  }

  Future<void> _saveSheet() async {
    if (_notes.isEmpty) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/piano_sheet_$timestamp.txt');

      final buffer = StringBuffer()
        ..writeln('Music Sheet - Piano')
        ..writeln('Tempo: $kBeatsPerMinute BPM')
        ..writeln('Disimpan: ${DateTime.now()}')
        ..writeln('---');
      for (final n in _notes) {
        buffer.writeln(
            '${n.name}\t${n.frequency.toStringAsFixed(2)} Hz\t${n.duration.label} note (${n.duration.symbol})');
      }
      await file.writeAsString(buffer.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tersimpan di ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    }
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Pilih durasi not, lalu tekan tuts',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            DurationSelector(
              selected: _selectedDuration,
              onChanged: (d) => setState(() => _selectedDuration = d),
            ),
            const SizedBox(height: 20),
            Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double keyboardWidth =
                      math.min(constraints.maxWidth, 560);
                  final double whiteKeyWidth =
                      keyboardWidth / _whiteFreqs.length;
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
                              onTapDown: (_) =>
                                  _playNote(_whiteNoteNames[i], _whiteFreqs[i]),
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
                          final double left =
                              whiteKeyWidth * (spec.afterWhiteIndex + 1) -
                                  (whiteKeyWidth * 0.3);
                          return Positioned(
                            left: left,
                            top: 0,
                            child: GestureDetector(
                              onTapDown: (_) => _playNote(spec.name, spec.freq),
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
            const SizedBox(height: 24),
            MusicSheetView(
              title: 'Music Sheet',
              notes: _notes,
              onSave: _saveSheet,
              onClear: _clearSheet,
              onPlay: _playSheet,
              onStop: _stopPlayback,
              isPlaying: _isPlaying,
              highlightedIndex: _playingIndex,
            ),
          ],
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