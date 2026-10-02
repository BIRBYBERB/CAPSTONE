import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TempoControls extends StatefulWidget {
  final int tempo;
  final ValueChanged<int> onTempoChanged;
  final bool metronomeEnabled;
  final ValueChanged<bool> onMetronomeChanged;

  const TempoControls({
    super.key,
    required this.tempo,
    required this.onTempoChanged,
    required this.metronomeEnabled,
    required this.onMetronomeChanged,
  });

  static const int minTempo = 40;
  static const int maxTempo = 240;

  @override
  State<TempoControls> createState() => _TempoControlsState();
}

class _TempoControlsState extends State<TempoControls> {
  late final TextEditingController _tempoController = TextEditingController(
    text: widget.tempo.toString(),
  );

  @override
  void didUpdateWidget(covariant TempoControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tempo != oldWidget.tempo &&
        _tempoController.text != widget.tempo.toString()) {
      _tempoController.text = widget.tempo.toString();
    }
  }

  @override
  void dispose() {
    _tempoController.dispose();
    super.dispose();
  }

  void _commitTempo(String value) {
    final parsedTempo = int.tryParse(value);
    if (parsedTempo == null ||
        parsedTempo < TempoControls.minTempo ||
        parsedTempo > TempoControls.maxTempo) {
      _tempoController.text = widget.tempo.toString();
      return;
    }
    widget.onTempoChanged(parsedTempo);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            SizedBox(
              width: 130,
              child: TextField(
                controller: _tempoController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Tempo',
                  suffixText: 'BPM',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: _commitTempo,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () =>
                  widget.onMetronomeChanged(!widget.metronomeEnabled),
              icon: Icon(
                widget.metronomeEnabled ? Icons.music_off : Icons.music_note,
              ),
              label: Text(
                widget.metronomeEnabled ? 'Metronom: On' : 'Metronom: Off',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
