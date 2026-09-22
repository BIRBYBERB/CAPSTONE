import 'package:flutter/material.dart';

import '../audio/note_duration.dart';

/// Lets the user pick which note value (whole, half, quarter, eighth,
/// sixteenth) the next note they play should be recorded as.
class DurationSelector extends StatelessWidget {
  final NoteDuration selected;
  final ValueChanged<NoteDuration> onChanged;

  const DurationSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: NoteDuration.values.map((d) {
        final bool isSelected = d == selected;
        return ChoiceChip(
          label: Text('${d.symbol}  ${d.label}'),
          selected: isSelected,
          onSelected: (_) => onChanged(d),
        );
      }).toList(),
    );
  }
}