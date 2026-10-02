import 'note_duration.dart';
import 'note_event.dart';

class MusicXmlExporter {
  static const int _divisionsPerQuarter = 4;
  static const int _beatsPerMeasure = 4;
  static const int _unitsPerMeasure = _divisionsPerQuarter * _beatsPerMeasure;
  static const List<_DurationValue> _durationValues = [
    _DurationValue(16, 'whole'),
    _DurationValue(8, 'half'),
    _DurationValue(4, 'quarter'),
    _DurationValue(2, 'eighth'),
    _DurationValue(1, '16th'),
  ];

  static String toMusicXml({
    required String title,
    required List<NoteEvent> notes,
    required int tempo,
  }) {
    if (notes.isEmpty) {
      throw ArgumentError.value(notes, 'notes', 'Must not be empty');
    }
    if (tempo <= 0) {
      throw ArgumentError.value(tempo, 'tempo', 'Must be greater than zero');
    }

    final measures = <List<String>>[[]];
    var measureUnits = 0;

    for (final note in notes) {
      var remainingUnits = (note.duration.beats * _divisionsPerQuarter).round();
      if (remainingUnits <= 0) {
        throw ArgumentError.value(
          note.duration,
          'duration',
          'Must be positive',
        );
      }
      final pitch = _parsePitch(note.name);
      final originalUnits = remainingUnits;
      var isFirstFragment = true;

      while (remainingUnits > 0) {
        if (measureUnits == _unitsPerMeasure) {
          measures.add([]);
          measureUnits = 0;
        }

        final availableUnits = _unitsPerMeasure - measureUnits;
        final fragmentUnits = _largestDurationAtMost(
          remainingUnits < availableUnits ? remainingUnits : availableUnits,
        );
        final hasMoreFragments = remainingUnits > fragmentUnits;
        final shouldTie =
            originalUnits != fragmentUnits ||
            !isFirstFragment ||
            hasMoreFragments;

        measures.last.add(
          _noteXml(
            pitch: pitch,
            units: fragmentUnits,
            tieStop: shouldTie && !isFirstFragment,
            tieStart: shouldTie && hasMoreFragments,
          ),
        );
        measureUnits += fragmentUnits;
        remainingUnits -= fragmentUnits;
        isFirstFragment = false;
      }
    }

    if (measureUnits > 0) {
      var paddingUnits = _unitsPerMeasure - measureUnits;
      while (paddingUnits > 0) {
        final restUnits = _largestDurationAtMost(paddingUnits);
        measures.last.add(_restXml(restUnits));
        paddingUnits -= restUnits;
      }
    }

    final escapedTitle = _escapeXml(title);
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8" standalone="no"?>')
      ..writeln(
        '<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">',
      )
      ..writeln('<score-partwise version="4.0">')
      ..writeln('<work><work-title>$escapedTitle</work-title></work>')
      ..writeln(
        '<identification><encoding><software>Virtual Instruments</software></encoding></identification>',
      )
      ..writeln(
        '<part-list><score-part id="P1"><part-name>$escapedTitle</part-name></score-part></part-list>',
      )
      ..writeln('<part id="P1">');

    for (var index = 0; index < measures.length; index++) {
      buffer.writeln('<measure number="${index + 1}">');
      if (index == 0) {
        buffer
          ..writeln('<attributes>')
          ..writeln('<divisions>$_divisionsPerQuarter</divisions>')
          ..writeln('<key><fifths>0</fifths><mode>major</mode></key>')
          ..writeln(
            '<time><beats>$_beatsPerMeasure</beats><beat-type>4</beat-type></time>',
          )
          ..writeln('<clef><sign>G</sign><line>2</line></clef>')
          ..writeln('</attributes>')
          ..writeln(
            '<direction placement="above"><direction-type><metronome><beat-unit>quarter</beat-unit><per-minute>$tempo</per-minute></metronome></direction-type><sound tempo="$tempo"/></direction>',
          );
      }
      for (final item in measures[index]) {
        buffer.writeln(item);
      }
      buffer.writeln('</measure>');
    }

    buffer
      ..writeln('</part>')
      ..writeln('</score-partwise>');
    return buffer.toString();
  }

  static int _largestDurationAtMost(int units) {
    for (final value in _durationValues) {
      if (value.units <= units) return value.units;
    }
    throw ArgumentError.value(units, 'units', 'Cannot notate this duration');
  }

  static String _noteXml({
    required _Pitch pitch,
    required int units,
    required bool tieStop,
    required bool tieStart,
  }) {
    final durationValue = _durationValues.firstWhere(
      (value) => value.units == units,
    );
    final buffer = StringBuffer()
      ..write('<note><pitch><step>${pitch.step}</step>');
    if (pitch.alter != 0) {
      buffer.write('<alter>${pitch.alter}</alter>');
    }
    buffer.write(
      '<octave>${pitch.octave}</octave></pitch><duration>$units</duration>',
    );
    if (tieStop) buffer.write('<tie type="stop"/>');
    if (tieStart) buffer.write('<tie type="start"/>');
    buffer.write('<voice>1</voice><type>${durationValue.type}</type>');
    if (tieStop || tieStart) {
      buffer.write('<notations>');
      if (tieStop) buffer.write('<tied type="stop"/>');
      if (tieStart) buffer.write('<tied type="start"/>');
      buffer.write('</notations>');
    }
    buffer.write('</note>');
    return buffer.toString();
  }

  static String _restXml(int units) {
    final durationValue = _durationValues.firstWhere(
      (value) => value.units == units,
    );
    return '<note><rest/><duration>$units</duration><voice>1</voice><type>${durationValue.type}</type></note>';
  }

  static _Pitch _parsePitch(String name) {
    final match = RegExp(r'^([A-G])([#b]?)(-?\d+)$').firstMatch(name);
    if (match == null) {
      throw FormatException('Nama nada tidak valid: $name');
    }

    final accidental = match.group(2);
    return _Pitch(
      step: match.group(1)!,
      alter: accidental == '#'
          ? 1
          : accidental == 'b'
          ? -1
          : 0,
      octave: int.parse(match.group(3)!),
    );
  }

  static String _escapeXml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

class _DurationValue {
  final int units;
  final String type;

  const _DurationValue(this.units, this.type);
}

class _Pitch {
  final String step;
  final int alter;
  final int octave;

  const _Pitch({required this.step, required this.alter, required this.octave});
}
