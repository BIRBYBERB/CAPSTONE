/// Represents one row from the `song_posts` table in Supabase: a file
/// (mp3 or mp4) the user uploaded, shown as a "post" in the feed.
class SongPost {
  final String id;
  final String songTitle;
  final String fileName;
  final String fileUrl;
  final String fileType; // 'audio' or 'video'
  final DateTime createdAt;
  final double score;

  SongPost({
    required this.id,
    required this.songTitle,
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.createdAt,
    required this.score,
  });

  String get storagePath {
    final segments = Uri.parse(fileUrl).pathSegments;
    for (var i = 0; i <= segments.length - 5; i++) {
      if (segments[i] == 'storage' &&
          segments[i + 1] == 'v1' &&
          segments[i + 2] == 'object' &&
          segments[i + 3] == 'public' &&
          segments[i + 4] == 'song-uploads') {
        final path = segments.skip(i + 5).join('/');
        if (path.isNotEmpty) return path;
      }
    }
    throw FormatException(
      'URL lagu tidak berisi jalur object Storage yang valid.',
    );
  }

  factory SongPost.fromMap(Map<String, dynamic> map) {
    return SongPost(
      id: map['id'] as String,
      songTitle: map['song_title'] as String,
      fileName: map['file_name'] as String,
      fileUrl: map['file_url'] as String,
      fileType: map['file_type'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      score: (map['score'] as num).toDouble(),
    );
  }
}
