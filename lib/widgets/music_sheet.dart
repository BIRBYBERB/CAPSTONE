import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/note_duration.dart';
import '../audio/note_event.dart';

/// Converts a frequency in Hz to a (fractional) MIDI note number.
/// Used only to decide how high/low to draw a note on the roll.
double _freqToMidi(double freq) => 69 + 12 * (math.log(freq / 440) / math.ln2);

/// A simple piano-roll style "music sheet": each played note appears in
/// order from left to right, positioned vertically by pitch (higher
/// note = higher up) and sized horizontally by its rhythmic duration
/// (a whole note is wider than a sixteenth note). This is a simplified
/// visualization rather than full staff notation, but it captures pitch,
/// order and rhythm.
///
/// The row can grow arbitrarily long as more notes are played, so it
/// scrolls horizontally with a always-visible scrollbar, and it
/// auto-scrolls to keep the newest / currently playing note in view.
class MusicSheetView extends StatefulWidget {
  final String title;
  final List<NoteEvent> notes;
  final VoidCallback onSave;
  final VoidCallback onClear;
  final VoidCallback onPlay;
  final VoidCallback onStop;
  final bool isPlaying;
  final int? highlightedIndex;

  const MusicSheetView({
    super.key,
    required this.title,
    required this.notes,
    required this.onSave,
    required this.onClear,
    required this.onPlay,
    required this.onStop,
    this.isPlaying = false,
    this.highlightedIndex,
  });

  static const double rollHeight = 160;
  static const double pixelsPerBeat = 40;
  static const double minColumnWidth = 34;
  // Fixed pitch range the roll maps onto, so the layout doesn't jump
  // around as new (possibly out-of-range) notes get added.
  static const double minMidi = 40; // roughly E2
  static const double maxMidi = 88; // roughly E6

  static double columnWidthFor(NoteDuration d) =>
      math.max(minColumnWidth, d.beats * pixelsPerBeat);

  @override
  State<MusicSheetView> createState() => _MusicSheetViewState();
}

class _MusicSheetViewState extends State<MusicSheetView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant MusicSheetView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool notesGrew = widget.notes.length > oldWidget.notes.length;
    final bool notesCleared =
        widget.notes.isEmpty && oldWidget.notes.isNotEmpty;
    final bool highlightMoved =
        widget.highlightedIndex != oldWidget.highlightedIndex &&
        widget.highlightedIndex != null;

    if (notesCleared) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
      });
    } else if (notesGrew || highlightMoved) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToRelevant());
    }
  }

  void _scrollToRelevant() {
    if (!_scrollController.hasClients || widget.notes.isEmpty) return;

    double target;
    if (widget.highlightedIndex != null) {
      // Keep the note currently being played in view.
      double cumulative = 0;
      for (
        int i = 0;
        i < widget.highlightedIndex! && i < widget.notes.length;
        i++
      ) {
        cumulative += MusicSheetView.columnWidthFor(widget.notes[i].duration);
      }
      target = cumulative;
    } else {
      // No note is actively playing: follow the newest note added.
      target = _scrollController.position.maxScrollExtent;
    }

    _scrollController.animateTo(
      target.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: (widget.notes.isEmpty || widget.isPlaying)
                  ? null
                  : widget.onClear,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: widget.notes.isEmpty
                  ? null
                  : (widget.isPlaying ? widget.onStop : widget.onPlay),
              icon: Icon(widget.isPlaying ? Icons.stop : Icons.play_arrow),
              label: Text(widget.isPlaying ? 'Stop' : 'Play'),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Unduh MusicXML',
              child: ElevatedButton.icon(
                onPressed: (widget.notes.isEmpty || widget.isPlaying)
                    ? null
                    : widget.onSave,
                icon: const Icon(Icons.download_outlined),
                label: const Text('XML'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Geser untuk melihat semua nada \u2192',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                Text(
                  'Unduh MusicXML untuk membuka atau mencetak partitur di MuseScore.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        Container(
          height: MusicSheetView.rollHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: widget.notes.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada nada dimainkan',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _GuideLinesPainter()),
                      ),
                      SingleChildScrollView(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(
                          bottom: 12,
                        ), // room for scrollbar
                        child: Row(
                          children: [
                            for (int i = 0; i < widget.notes.length; i++)
                              _NoteMarker(
                                note: widget.notes[i],
                                isHighlighted: i == widget.highlightedIndex,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _NoteMarker extends StatelessWidget {
  final NoteEvent note;
  final bool isHighlighted;
  const _NoteMarker({required this.note, this.isHighlighted = false});

  @override
  Widget build(BuildContext context) {
    final double midi = _freqToMidi(note.frequency)
        .clamp(MusicSheetView.minMidi, MusicSheetView.maxMidi);
    final double t =
        (midi - MusicSheetView.minMidi) /
        (MusicSheetView.maxMidi - MusicSheetView.minMidi);

    final double columnWidth = MusicSheetView.columnWidthFor(note.duration);

    const double markerSize = 18;
    const double labelHeight = 30;
    final double usableHeight =
        MusicSheetView.rollHeight - markerSize - labelHeight;
    // Higher pitch (higher t) should sit higher up (smaller top offset).
    final double top = (1 - t) * usableHeight;

    return SizedBox(
      width: columnWidth,
      height: MusicSheetView.rollHeight,
      child: Stack(
        children: [
          Positioned(
            top: top,
            left:
                (columnWidth - markerSize) / 2 -
                (isHighlighted ? 3 : 0), // keep centered while growing
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: isHighlighted ? markerSize + 6 : markerSize,
              height: isHighlighted ? markerSize + 6 : markerSize,
              decoration: BoxDecoration(
                color: isHighlighted
                    ? Colors.orange
                    : Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
          Positioned(
            top: top + markerSize + 2,
            left: 0,
            right: 0,
            child: Text(
              note.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
          Positioned(
            top: top + markerSize + 16,
            left: 0,
            right: 0,
            child: Text(
              note.duration.symbol,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;
    const int lineCount = 5;
    for (int i = 1; i < lineCount; i++) {
      final double y = size.height * (i / lineCount);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
