import 'package:flutter_test/flutter_test.dart';
import 'package:projectcapstone/audio/musicxml_exporter.dart';
import 'package:projectcapstone/audio/note_duration.dart';
import 'package:projectcapstone/audio/note_event.dart';

void main() {
  group('MusicXmlExporter', () {
    test('exports pitches, durations, tempo, and complete 4/4 measures', () {
      final notes = List.generate(
        5,
        (_) => NoteEvent(
          name: 'C4',
          frequency: 261.63,
          duration: NoteDuration.quarter,
        ),
      );

      final xml = MusicXmlExporter.toMusicXml(
        title: 'Piano & Sasando',
        notes: notes,
        tempo: 120,
      );

      expect(xml, contains('<work-title>Piano &amp; Sasando</work-title>'));
      expect(xml, contains('<per-minute>120</per-minute>'));
      expect(xml, contains('<step>C</step><octave>4</octave>'));
      expect(_measureDurations(xml), [16, 16]);
    });

    test('writes accidentals and ties notes across bar lines', () {
      final notes = [
        for (var i = 0; i < 3; i++)
          NoteEvent(
            name: 'D4',
            frequency: 293.66,
            duration: NoteDuration.quarter,
          ),
        NoteEvent(name: 'F#4', frequency: 369.99, duration: NoteDuration.whole),
      ];

      final xml = MusicXmlExporter.toMusicXml(
        title: 'Sasando',
        notes: notes,
        tempo: 96,
      );

      expect(xml, contains('<step>F</step><alter>1</alter><octave>4</octave>'));
      expect(xml, contains('<tie type="start"/>'));
      expect(xml, contains('<tie type="stop"/>'));
      expect(_measureDurations(xml), [16, 16]);
    });

    test('rejects empty scores and non-positive tempos', () {
      expect(
        () => MusicXmlExporter.toMusicXml(
          title: 'Empty',
          notes: const [],
          tempo: 96,
        ),
        throwsArgumentError,
      );
      expect(
        () => MusicXmlExporter.toMusicXml(
          title: 'Piano',
          notes: [
            NoteEvent(
              name: 'C4',
              frequency: 261.63,
              duration: NoteDuration.quarter,
            ),
          ],
          tempo: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}

List<int> _measureDurations(String xml) {
  final measurePattern = RegExp(
    r'<measure number="\d+">(.*?)</measure>',
    dotAll: true,
  );
  final durationPattern = RegExp(r'<duration>(\d+)</duration>');

  return measurePattern.allMatches(xml).map((measure) {
    return durationPattern
        .allMatches(measure.group(1)!)
        .fold<int>(0, (sum, duration) => sum + int.parse(duration.group(1)!));
  }).toList();
}
