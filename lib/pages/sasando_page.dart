import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../audio/note_duration.dart';
import '../audio/note_event.dart';
import '../audio/oboe_engine.dart';
import '../audio/player_pool.dart';
import '../audio/tempo.dart';
import '../audio/tone_synth.dart';
import '../widgets/duration_selector.dart';
import '../widgets/music_sheet.dart';

/// Halaman Instrumen Virtual Sasando Tradisional
/// Dilengkapi dengan:
/// - Real-time Low-Latency Audio (Google Oboe Engine)
/// - Velocity Dynamics (kekuatan petikan berdasarkan kecepatan jari)
/// - Haptic Feedback (sensasi getaran fisik dawai)
/// - String Vibration Physics (simulasi gelombang dawai bergetar)
/// - Lifecycle Management (hemat baterai & memori)
class SasandoPage extends StatefulWidget {
  const SasandoPage({super.key});

  @override
  State<SasandoPage> createState() => _SasandoPageState();
}

class _SasandoPageState extends State<SasandoPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final PlayerPool _pool = PlayerPool();
  final List<NoteEvent> _notes = [];
  NoteDuration _selectedDuration = NoteDuration.quarter;
  bool _isPlaying = false;
  int? _playingIndex;

  // Tangga nada diatonis 2 oktaf khas Sasando (mulai dari G3)
  late final List<double> _stringFreqs = _buildScale();
  static const List<String> _stringNames = [
    'G3', 'A3', 'B3', 'C4', 'D4', 'E4', 'F#4', 'G4',
    'G4', 'A4', 'B4', 'C5', 'D5', 'E5', 'F#5', 'G5',
  ];

  // Visual Physics & Interaction state
  late final AnimationController _physicsController;
  final List<double> _amplitudes = List.filled(16, 0.0);
  final List<double> _phases = List.filled(16, 0.0);
  int? _lastPluckedIndex;
  DateTime _lastPluckTime = DateTime.now();
  double _lastTouchPositionX = 0.0;

  List<double> _buildScale() {
    const double g3 = 196.00;
    const List<double> steps = [0, 2, 4, 5, 7, 9, 11, 12];
    final List<double> freqs = [];
    for (int octave = 0; octave < 2; octave++) {
      for (final s in steps) {
        final semitone = s + (octave * 12);
        freqs.add(g3 * math.pow(2, semitone / 12));
      }
    }
    return freqs; // 16 strings
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Inisialisasi Oboe Engine saat masuk halaman
    OboeEngine.init();

    // Physics Engine Loop untuk merender osilasi getaran senar
    _physicsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_updateStringPhysics);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Penghematan Baterai & CPU: Matikan Oboe saat background, nyalakan saat resume
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      OboeEngine.dispose();
    } else if (state == AppLifecycleState.resumed) {
      OboeEngine.init();
    }
  }

  void _updateStringPhysics() {
    bool hasActiveVibration = false;
    for (int i = 0; i < 16; i++) {
      if (_amplitudes[i] > 0.001) {
        _amplitudes[i] *= 0.94; // Peluruhan amplitudo senar (damping)
        _phases[i] += 0.45 + (i * 0.02); // Frekuensi osilasi visual
        hasActiveVibration = true;
      } else {
        _amplitudes[i] = 0.0;
      }
    }

    if (hasActiveVibration) {
      setState(() {});
    } else if (_physicsController.isAnimating) {
      _physicsController.stop();
    }
  }

  void _pluck(int index, {double velocity = 0.85}) {
    if (index < 0 || index >= _stringFreqs.length) return;

    // 1. Taktil Fisik (Haptic Feedback)
    if (velocity > 0.7) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    // 2. Audio Engine (Oboe Low Latency atau Fallback)
    if (OboeEngine.isAvailable) {
      OboeEngine.pluck(_stringFreqs[index], velocity: velocity.clamp(0.2, 1.0));
    } else {
      final double ms = beatsToMilliseconds(_selectedDuration.beats);
      final wav = ToneSynth.generate(
        frequency: _stringFreqs[index],
        durationSeconds: ms / 1000,
        plucked: true,
      );
      _pool.play(wav);
    }

    // 3. Picu Fisika Getaran Senar
    _amplitudes[index] = velocity.clamp(0.3, 1.0);
    _phases[index] = 0.0;
    if (!_physicsController.isAnimating) {
      _physicsController.repeat();
    }

    // 4. Catat ke Lembar Notasi Musik
    setState(() {
      _lastPluckedIndex = index;
      _notes.add(NoteEvent(
        name: _stringNames[index],
        frequency: _stringFreqs[index],
        duration: _selectedDuration,
      ));
    });
  }

  void _onPanStart(DragStartDetails details, double spacing, int stringCount) {
    _lastTouchPositionX = details.localPosition.dx;
    _lastPluckTime = DateTime.now();
    _handleTouch(details.localPosition.dx, spacing, stringCount, initialVelocity: 0.8);
  }

  void _onPanUpdate(DragUpdateDetails details, double spacing, int stringCount) {
    final now = DateTime.now();
    final dt = now.difference(_lastPluckTime).inMilliseconds;
    final dx = (details.localPosition.dx - _lastTouchPositionX).abs();

    // Hitung kecepatan gesekan jari (Velocity Dynamics)
    double calculatedVelocity = 0.75;
    if (dt > 0) {
      final speed = dx / dt; // Pixel per millisecond
      calculatedVelocity = (speed * 0.45).clamp(0.4, 1.0);
    }

    _lastTouchPositionX = details.localPosition.dx;
    _lastPluckTime = now;

    _handleTouch(details.localPosition.dx, spacing, stringCount, initialVelocity: calculatedVelocity);
  }

  void _handleTouch(double dx, double spacing, int stringCount, {double initialVelocity = 0.8}) {
    final int index = (dx / spacing).floor().clamp(0, stringCount - 1);
    if (index != _lastPluckedIndex) {
      _pluck(index, velocity: initialVelocity);
    }
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

      if (OboeEngine.isAvailable) {
        OboeEngine.pluck(note.frequency, velocity: 0.9);
      } else {
        final wav = ToneSynth.generate(
          frequency: note.frequency,
          durationSeconds: ms / 1000,
          plucked: true,
        );
        _pool.play(wav);
      }

      // Animasi dawai bergetar saat playback
      final idx = _stringNames.indexOf(note.name);
      if (idx != -1) {
        _amplitudes[idx] = 0.9;
        if (!_physicsController.isAnimating) _physicsController.repeat();
      }

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
      final file = File('${dir.path}/sasando_sheet_$timestamp.txt');

      final buffer = StringBuffer()
        ..writeln('Music Sheet - Sasando')
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
    WidgetsBinding.instance.removeObserver(this);
    _physicsController.dispose();
    _pool.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1712), // Nuansa kayu tradisional
      appBar: AppBar(
        title: const Text('Sasando Rote'),
        backgroundColor: const Color(0xFF2C2018),
        foregroundColor: const Color(0xFFEAD8C7),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Redam Senar (Mute)',
            icon: const Icon(Icons.waves, color: Color(0xFFD4AF37)),
            onPressed: () {
              HapticFeedback.selectionClick();
              for (int i = 0; i < 16; i++) {
                _amplitudes[i] = 0.0;
              }
              setState(() {});
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
          child: Column(
            children: [
              // Panel Durasi Not
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2019),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF4A382A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app, size: 18, color: Color(0xFFD4AF37)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Petik atau gesek senar dawai Sasando',
                        style: TextStyle(color: Color(0xFFD0C3B5), fontSize: 13),
                      ),
                    ),
                    DurationSelector(
                      selected: _selectedDuration,
                      onChanged: (d) => setState(() => _selectedDuration = d),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Bodi Sasando & Senar Fisik
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final int stringCount = _stringFreqs.length;
                    final double width = constraints.maxWidth;
                    final double stringSpacing = width / stringCount;

                    return GestureDetector(
                      onPanStart: (d) => _onPanStart(d, stringSpacing, stringCount),
                      onPanUpdate: (d) => _onPanUpdate(d, stringSpacing, stringCount),
                      onPanEnd: (_) => setState(() => _lastPluckedIndex = null),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF3B291A),
                              Color(0xFF5A3E26),
                              Color(0xFF3B291A),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(color: const Color(0xFF7D5A38), width: 1.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Stack(
                            children: [
                              // Tekstur Bambu Resonator di Belakang
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: BambooTexturePainter(),
                                ),
                              ),

                              // Renderer Getaran Fisik Senar
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: SasandoStringsPainter(
                                    stringCount: stringCount,
                                    stringNames: _stringNames,
                                    amplitudes: _amplitudes,
                                    phases: _phases,
                                  ),
                                ),
                              ),

                              // Area Tap Tiap Senar
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: List.generate(stringCount, (i) {
                                  return Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTapDown: (_) => _pluck(i, velocity: 0.9),
                                      child: const SizedBox.expand(),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Music Sheet Notasi Musik
              MusicSheetView(
                title: 'Lembar Notasi Sasando',
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
      ),
    );
  }
}

/// Painter untuk merender 16 senar dawai Sasando dengan osilasi gelombang fisik
class SasandoStringsPainter extends CustomPainter {
  final int stringCount;
  final List<String> stringNames;
  final List<double> amplitudes;
  final List<double> phases;

  SasandoStringsPainter({
    required this.stringCount,
    required this.stringNames,
    required this.amplitudes,
    required this.phases,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double spacing = size.width / stringCount;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < stringCount; i++) {
      final double x = (i + 0.5) * spacing;
      final double amp = amplitudes[i];
      final double phase = phases[i];

      // Garis Senar dengan Efek Getar (Sine wave displacement)
      final Path path = Path();
      path.moveTo(x, 28);

      final double maxOffset = amp * 7.0 * math.sin(phase);
      path.quadraticBezierTo(
        x + maxOffset,
        size.height / 2,
        x,
        size.height - 28,
      );

      final Paint stringPaint = Paint()
        ..color = amp > 0.05
            ? const Color(0xFFFFD700) // Kuning keemasan bersinar saat bergetar
            : const Color(0xFFD8C3A5).withValues(alpha: 0.7) // Warna senar perak/baja
        ..strokeWidth = (i < 8 ? 1.8 : 1.2) + (amp * 1.0) // Senar bass lebih tebal
        ..style = PaintingStyle.stroke;

      canvas.drawPath(path, stringPaint);

      // Label Nada di Bagian Atas
      final spanTop = TextSpan(
        text: stringNames[i],
        style: TextStyle(
          color: amp > 0.05 ? const Color(0xFFFFD700) : const Color(0xFFB09B88),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.text = spanTop;
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - (textPainter.width / 2), 8),
      );

      // Titik Pin Dawai di Bawah
      final Paint pinPaint = Paint()
        ..color = const Color(0xFF8B5A2B)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, size.height - 14), 3.5, pinPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SasandoStringsPainter oldDelegate) => true;
}

/// Painter untuk aksen motif bambu & lontar pada bodi Sasando
class BambooTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..strokeWidth = 1.0;

    for (double y = 40; y < size.height - 40; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
