import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// A tiny pool of AudioPlayers so overlapping notes can ring together
/// (polyphony) instead of cutting each other off.
class PlayerPool {
  final List<AudioPlayer> _players =
      List.generate(10, (_) => AudioPlayer()..setReleaseMode(ReleaseMode.stop));
  int _cursor = 0;

  Future<void> play(Uint8List wavBytes) async {
    final player = _players[_cursor];
    _cursor = (_cursor + 1) % _players.length;
    await player.stop();
    await player.play(BytesSource(wavBytes));
  }

  void dispose() {
    for (final p in _players) {
      p.dispose();
    }
  }
}