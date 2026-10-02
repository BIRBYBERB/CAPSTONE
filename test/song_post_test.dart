import 'package:flutter_test/flutter_test.dart';
import 'package:projectcapstone/models/song_post.dart';

void main() {
  group('SongPost.storagePath', () {
    test('extracts and decodes the path within the public storage bucket', () {
      final post = _post(
        'https://example.supabase.co/storage/v1/object/public/song-uploads/'
        '12345_My%20Song.mp3',
      );

      expect(post.storagePath, '12345_My Song.mp3');
    });

    test('rejects URLs outside the expected bucket', () {
      final post = _post(
        'https://example.supabase.co/storage/v1/object/public/other-bucket/song.mp3',
      );

      expect(() => post.storagePath, throwsFormatException);
    });
  });
}

SongPost _post(String fileUrl) => SongPost(
  id: 'song-1',
  songTitle: 'Song',
  fileName: 'song.mp3',
  fileUrl: fileUrl,
  fileType: 'audio',
  createdAt: DateTime.utc(2026),
  score: 0,
);
