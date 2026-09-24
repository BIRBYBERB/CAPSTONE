/// Represents one row from the `song_posts` table in Supabase: a file
/// (mp3 or mp4) the user uploaded, shown as a "post" in the feed.
class SongPost {
  final String id;
  final String fileName;
  final String fileUrl;
  final String fileType; // 'audio' or 'video'
  final DateTime createdAt;

  SongPost({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.createdAt,
  });

  factory SongPost.fromMap(Map<String, dynamic> map) {
    return SongPost(
      id: map['id'] as String,
      fileName: map['file_name'] as String,
      fileUrl: map['file_url'] as String,
      fileType: map['file_type'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}