class SongComment {
  final String id;
  final String songPostId;
  final String commentText;
  final DateTime createdAt;

  const SongComment({
    required this.id,
    required this.songPostId,
    required this.commentText,
    required this.createdAt,
  });

  factory SongComment.fromMap(Map<String, dynamic> map) {
    return SongComment(
      id: map['id'].toString(),
      songPostId: map['song_post_id'].toString(),
      commentText: map['comment_text'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
