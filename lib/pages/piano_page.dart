import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/export_file_saver.dart';
import '../audio/musicxml_exporter.dart';
import '../audio/note_duration.dart';
import '../audio/note_event.dart';
import '../audio/player_pool.dart';
import '../audio/tempo.dart';
import '../audio/tone_synth.dart';
import '../widgets/duration_selector.dart';
import '../widgets/music_sheet.dart';
import '../widgets/tempo_controls.dart';

class PianoPage extends StatefulWidget {
  const PianoPage({super.key});

  @override
  State<PianoPage> createState() => _PianoPageState();
}

class _PianoPageState extends State<PianoPage> {
  final PlayerPool _pool = PlayerPool();
  final List<NoteEvent> _notes = [];
  NoteDuration _selectedDuration = NoteDuration.quarter;
  int _tempoBpm = kBeatsPerMinute;
  bool _metronomeEnabled = false;
  bool _isPlaying = false;
  int? _playingIndex;
  final Uint8List _regularMetronomeClick = ToneSynth.generate(
    frequency: 1000,
    durationSeconds: 0.04,
  );
  final Uint8List _accentMetronomeClick = ToneSynth.generate(
    frequency: 1500,
    durationSeconds: 0.04,
  );

  // White keys C4..C5, plus sharps mapped by position.
  static const List<String> _whiteNoteNames = [
    'C4',
    'D4',
    'E4',
    'F4',
    'G4',
    'A4',
    'B4',
    'C5',
  ];
  static const List<double> _whiteFreqs = [
    261.63,
    293.66,
    329.63,
    349.23,
    392.00,
    440.00,
    493.88,
    523.25,
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
    final double ms = beatsToMilliseconds(
      _selectedDuration.beats,
      bpm: _tempoBpm,
    );
    final wav = ToneSynth.generate(
      frequency: freq,
      durationSeconds: ms / 1000,
      plucked: false,
    );
    unawaited(_pool.play(wav));

    setState(() {
      _notes.add(
        NoteEvent(name: name, frequency: freq, duration: _selectedDuration),
      );
    });
  }

  void _clearSheet() {
    setState(() => _notes.clear());
  }

  Future<void> _playSheet() async {
    if (_notes.isEmpty || _isPlaying) return;
    setState(() => _isPlaying = true);

    double elapsedBeats = 0;
    int beatIndex = 0;
    if (_metronomeEnabled) {
      _playMetronomeClick(beatIndex++);
    }

    for (int i = 0; i < _notes.length; i++) {
      if (!_isPlaying || !mounted) break;
      final note = _notes[i];
      final int bpm = _tempoBpm;
      final double ms = beatsToMilliseconds(note.duration.beats, bpm: bpm);

      final wav = ToneSynth.generate(
        frequency: note.frequency,
        durationSeconds: ms / 1000,
        plucked: false,
      );
      await _pool.play(wav);
      setState(() => _playingIndex = i);

      double beatsRemaining = note.duration.beats;
      while (beatsRemaining > 0 && _isPlaying && mounted) {
        final double remainder = elapsedBeats % 1;
        final double beatsToNextTick = remainder < 1e-9 ? 1 : 1 - remainder;
        final double segmentBeats = math.min(beatsRemaining, beatsToNextTick);
        final double segmentMs = beatsToMilliseconds(segmentBeats, bpm: bpm);

        await Future.delayed(Duration(milliseconds: segmentMs.round()));
        elapsedBeats += segmentBeats;
        beatsRemaining -= segmentBeats;

        if (_metronomeEnabled &&
            (elapsedBeats - elapsedBeats.round()).abs() < 1e-9) {
          _playMetronomeClick(beatIndex++);
        }
      }
    }

    if (mounted) {
      setState(() {
        _isPlaying = false;
        _playingIndex = null;
      });
    }
  }

  void _playMetronomeClick(int beatIndex) {
    final click = beatIndex % 4 == 0
        ? _accentMetronomeClick
        : _regularMetronomeClick;
    unawaited(_pool.play(click));
  }

  void _stopPlayback() {
    setState(() => _isPlaying = false);
  }

  Future<void> _saveSheet() async {
    if (_notes.isEmpty) return;
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final xml = MusicXmlExporter.toMusicXml(
        title: 'Piano',
        notes: _notes,
        tempo: _tempoBpm,
      );
      final saved = await saveExportFile(
        fileName: 'piano_sheet_$timestamp.musicxml',
        mimeType: 'application/vnd.recordare.musicxml+xml',
        bytes: Uint8List.fromList(utf8.encode(xml)),
      );
      if (!saved) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Partitur berhasil diunduh.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
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
            const SizedBox(height: 12),
            TempoControls(
              tempo: _tempoBpm,
              onTempoChanged: (tempo) => setState(() => _tempoBpm = tempo),
              metronomeEnabled: _metronomeEnabled,
              onMetronomeChanged: (enabled) =>
                  setState(() => _metronomeEnabled = enabled),
            ),
            const SizedBox(height: 20),
            Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double keyboardWidth = math.min(
                    constraints.maxWidth,
                    560,
                  );
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
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.grey.shade400,
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(6),
                                  ),
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
                                    bottom: Radius.circular(4),
                                  ),
                                ),
                                alignment: Alignment.bottomCenter,
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  spec.name,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 9,
                                  ),
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
