import 'package:flutter_test/flutter_test.dart';
import 'package:projectcapstone/models/song_comment.dart';

void main() {
  test('parses persisted comment data', () {
    final comment = SongComment.fromMap({
      'id': 3,
      'song_post_id': 'post-1',
      'comment_text': 'Nice melody',
      'created_at': '2026-10-02T00:00:00Z',
    });

    expect(comment.id, '3');
    expect(comment.songPostId, 'post-1');
    expect(comment.commentText, 'Nice melody');
    expect(comment.createdAt, DateTime.utc(2026, 10, 2));
  });
}
