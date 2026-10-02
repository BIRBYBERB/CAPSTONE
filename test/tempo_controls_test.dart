import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projectcapstone/widgets/tempo_controls.dart';

void main() {
  testWidgets('accepts a tempo and toggles the metronome', (tester) async {
    var tempo = 96;
    var metronomeEnabled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TempoControls(
            tempo: tempo,
            onTempoChanged: (value) => tempo = value,
            metronomeEnabled: metronomeEnabled,
            onMetronomeChanged: (value) => metronomeEnabled = value,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '140');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(tempo, 140);

    await tester.tap(find.text('Metronom: Off'));
    expect(metronomeEnabled, isTrue);
  });

  testWidgets('rejects values outside the supported tempo range', (
    tester,
  ) async {
    var tempo = 96;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TempoControls(
            tempo: tempo,
            onTempoChanged: (value) => tempo = value,
            metronomeEnabled: false,
            onMetronomeChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '300');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(tempo, 96);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '96',
    );
  });
}
