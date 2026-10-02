import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/export_file_saver.dart';
import '../audio/musicxml_exporter.dart';
import '../audio/note_duration.dart';
import '../audio/note_event.dart';
import '../plugins/oboe_engine.dart';
import '../audio/player_pool.dart';
import '../audio/tempo.dart';
import '../audio/tone_synth.dart';
import '../widgets/duration_selector.dart';
import '../widgets/music_sheet.dart';
import '../widgets/tempo_controls.dart';

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

  // Two octaves of a diatonic (major) scale starting at G3, a fairly
  // typical open-string spread for a sasando.
  late final List<double> _stringFreqs = _buildScale();
  static const List<String> _stringNames = [
    'G3',
    'A3',
    'B3',
    'C4',
    'D4',
    'E4',
    'F#4',
    'G4',
    'G4',
    'A4',
    'B4',
    'C5',
    'D5',
    'E5',
    'F#5',
    'G5',
  ];
  int? _lastPluckedIndex;

  List<double> _buildScale() {
    const double g3 = 196.00;
    const List<double> steps = [
      0,
      2,
      4,
      5,
      7,
      9,
      11,
      12,
    ]; // major scale, semitones
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

    if (OboeEngine.isAvailable) {
      OboeEngine.pluck(_stringFreqs[index]);
    } else {
      final double ms = beatsToMilliseconds(
        _selectedDuration.beats,
        bpm: _tempoBpm,
      );
      final wav = ToneSynth.generate(
        frequency: _stringFreqs[index],
        durationSeconds: ms / 1000,
        plucked: true,
      );
      unawaited(_pool.play(wav));
    }

    setState(() {
      _lastPluckedIndex = index;
      _notes.add(
        NoteEvent(
          name: _stringNames[index],
          frequency: _stringFreqs[index],
          duration: _selectedDuration,
        ),
      );
    });
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted && _lastPluckedIndex == index) {
        setState(() => _lastPluckedIndex = null);
      }
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

      if (OboeEngine.isAvailable) {
        OboeEngine.pluck(note.frequency);
      } else {
        final wav = ToneSynth.generate(
          frequency: note.frequency,
          durationSeconds: ms / 1000,
          plucked: true,
        );
        await _pool.play(wav);
      }
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
        title: 'Sasando',
        notes: _notes,
        tempo: _tempoBpm,
      );
      final saved = await saveExportFile(
        fileName: 'sasando_sheet_$timestamp.musicxml',
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
      appBar: AppBar(title: const Text('Sasando')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Pilih durasi not, lalu tap atau seret di senar',
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
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final int stringCount = _stringFreqs.length;
                  final double width = constraints.maxWidth;
                  final double stringSpacing = width / stringCount;

                  return GestureDetector(
                    onPanStart: (details) => _pluckFromPosition(
                      details.localPosition.dx,
                      stringSpacing,
                      stringCount,
                    ),
                    onPanUpdate: (details) => _pluckFromPosition(
                      details.localPosition.dx,
                      stringSpacing,
                      stringCount,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.brown.shade100,
                            Colors.brown.shade200,
                          ],
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
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 90,
                                      ),
                                      width: plucked ? 4 : 2,
                                      color: plucked
                                          ? Colors.deepPurple
                                          : Colors.brown.shade700,
                                    ),
                                    Positioned(
                                      bottom: 10,
                                      child: Text(
                                        _stringNames[i],
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 9,
                                        ),
                                      ),
                                    ),
                                  ],
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
            const SizedBox(height: 16),
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

  void _pluckFromPosition(double dx, double spacing, int stringCount) {
    final int index = (dx / spacing).floor().clamp(0, stringCount - 1);
    if (index != _lastPluckedIndex) {
      _pluck(index);
    }
  }
}
