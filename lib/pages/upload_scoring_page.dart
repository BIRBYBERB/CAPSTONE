import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/song_comment.dart';
import '../models/song_post.dart';
import '../widgets/upload_preview_dialog.dart';

class UploadScoringPage extends StatefulWidget {
  const UploadScoringPage({super.key});

  @override
  State<UploadScoringPage> createState() => _UploadScoringPageState();
}

class _UploadScoringPageState extends State<UploadScoringPage> {
  static const String _bucketName = 'song-uploads';
  static const String _tableName = 'song_posts';
  static const String _commentsTableName = 'song_comments';

  final SupabaseClient _supabase = Supabase.instance.client;
  final AudioPlayer _player = AudioPlayer();

  List<SongPost> _posts = [];
  Map<String, List<SongComment>> _commentsByPostId = {};
  bool _isLoading = true;
  bool _isUploading = false;
  String? _playingPostId;
  String? _deletingPostId;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingPostId = null);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from(_tableName)
          .select()
          .order('created_at', ascending: false);
      final posts = (data as List)
          .map((row) => SongPost.fromMap(row as Map<String, dynamic>))
          .toList();
      final comments = posts.isEmpty
          ? <SongComment>[]
          : (await _supabase
                    .from(_commentsTableName)
                    .select()
                    .inFilter(
                      'song_post_id',
                      posts.map((post) => post.id).toList(),
                    )
                    .order('created_at'))
                .map((row) => SongComment.fromMap(row))
                .toList();
      final commentsByPostId = <String, List<SongComment>>{};
      for (final comment in comments) {
        commentsByPostId.putIfAbsent(comment.songPostId, () => []).add(comment);
      }

      setState(() {
        _posts = posts;
        _commentsByPostId = commentsByPostId;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal memuat daftar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'mp4'],
      withData: true, // needed so bytes are available on every platform
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final picked = result.files.first;
    final bytes = picked.bytes;
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak bisa membaca file yang dipilih')),
        );
      }
      return;
    }

    final String extension = (picked.extension ?? 'mp3').toLowerCase();
    final songTitle = await showDialog<String>(
      context: context,
      builder: (_) => UploadPreviewDialog(file: picked, bytes: bytes),
    );
    if (songTitle == null || !mounted) return;
    final String fileType = extension == 'mp4' ? 'video' : 'audio';
    final String storagePath =
        '${DateTime.now().millisecondsSinceEpoch}_${picked.name}';

    setState(() => _isUploading = true);
    try {
      await _supabase.storage
          .from(_bucketName)
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: fileType == 'video' ? 'video/mp4' : 'audio/mpeg',
            ),
          );

      final String publicUrl = _supabase.storage
          .from(_bucketName)
          .getPublicUrl(storagePath);

      await _supabase.from(_tableName).insert({
        'song_title': songTitle,
        'file_name': picked.name,
        'file_url': publicUrl,
        'file_type': fileType,
        'score': 0,
      });

      await _loadPosts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal upload: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _addComment(SongPost post) async {
    final controller = TextEditingController();
    try {
      final commentText = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Komentar: ${post.songTitle}'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            maxLength: 1000,
            decoration: const InputDecoration(
              hintText: 'Tulis komentar atau kritik yang membangun',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              final text = value.trim();
              if (text.isNotEmpty) Navigator.of(dialogContext).pop(text);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) Navigator.of(dialogContext).pop(text);
              },
              child: const Text('Kirim'),
            ),
          ],
        ),
      );
      if (commentText == null || !mounted) return;

      await _supabase.from(_commentsTableName).insert({
        'song_post_id': post.id,
        'comment_text': commentText,
      });
      await _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mengirim komentar: $e')));
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _loadComments() async {
    if (_posts.isEmpty) {
      if (mounted) setState(() => _commentsByPostId = {});
      return;
    }
    final rows = await _supabase
        .from(_commentsTableName)
        .select()
        .inFilter('song_post_id', _posts.map((post) => post.id).toList())
        .order('created_at');
    final commentsByPostId = <String, List<SongComment>>{};
    for (final row in rows) {
      final comment = SongComment.fromMap(row);
      commentsByPostId.putIfAbsent(comment.songPostId, () => []).add(comment);
    }
    if (mounted) setState(() => _commentsByPostId = commentsByPostId);
  }

  Future<void> _togglePlay(SongPost post) async {
    if (_playingPostId == post.id) {
      await _player.stop();
      setState(() => _playingPostId = null);
      return;
    }
    await _player.stop();
    await _player.play(UrlSource(post.fileUrl));
    setState(() => _playingPostId = post.id);
  }

  Future<void> _deletePost(SongPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus lagu?'),
        content: Text(
          'Post "${post.songTitle}", komentarnya, dan file lagu akan dihapus permanen. '
          'Dalam mode demo tanpa login, lagu ini dapat dihapus siapa saja.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingPostId = post.id);
    var rowDeleted = false;
    try {
      if (_playingPostId == post.id) {
        await _player.stop();
        if (mounted) setState(() => _playingPostId = null);
      }

      final deletedRows = await _supabase
          .from(_tableName)
          .delete()
          .eq('id', post.id)
          .select('id');
      if (deletedRows.isEmpty) {
        throw StateError(
          'Supabase tidak menghapus baris. Periksa izin DELETE pada tabel song_posts.',
        );
      }
      rowDeleted = true;

      await _supabase.storage.from(_bucketName).remove([post.storagePath]);
      await _loadPosts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lagu dan file berhasil dihapus.')),
        );
      }
    } catch (e) {
      if (rowDeleted) {
        await _loadPosts();
      }
      if (mounted) {
        final message = rowDeleted
            ? 'Data lagu sudah dihapus, tetapi file Storage gagal dihapus. '
                  'Periksa izin DELETE pada bucket song-uploads: $e'
            : 'Gagal menghapus lagu. Periksa izin DELETE di Supabase: $e';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _deletingPostId = null);
    }
  }

  Future<void> _showPostDetails(SongPost post) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final comments = _commentsByPostId[post.id] ?? const <SongComment>[];
          final isPlaying = _playingPostId == post.id;
          return AlertDialog(
            title: Text(post.songTitle),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Diunggah ${_formatTime(post.createdAt)}'),
                    const SizedBox(height: 8),
                    Text(
                      post.score == 0
                          ? 'Skor: 0 (belum dinilai)'
                          : 'Skor: ${post.score.toStringAsFixed(1)}',
                    ),
                    Text(
                      post.fileName,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        await _togglePlay(post);
                        if (dialogContext.mounted) setDialogState(() {});
                      },
                      icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
                      label: Text(isPlaying ? 'Hentikan lagu' : 'Putar lagu'),
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Komentar (${comments.length})',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _deletingPostId != null
                              ? null
                              : () async {
                                  await _addComment(post);
                                  if (dialogContext.mounted) {
                                    setDialogState(() {});
                                  }
                                },
                          icon: const Icon(Icons.add_comment_outlined),
                          label: const Text('Tulis'),
                        ),
                      ],
                    ),
                    if (comments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Belum ada komentar.'),
                      )
                    else
                      ...comments.map(
                        (comment) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_outline),
                          ),
                          title: const Text('Pengguna'),
                          subtitle: Text(
                            '${_formatTime(comment.createdAt)}\n'
                            '${comment.commentText}',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Tutup'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload and Scoring Songs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _uploadFile,
        icon: _isUploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.upload_file),
        label: Text(_isUploading ? 'Mengunggah...' : 'Upload'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _posts.isEmpty
            ? ListView(
                // ListView so pull-to-refresh still works when empty
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'Belum ada lagu yang diunggah.\nTekan tombol Upload untuk mulai.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  final bool isDeleting = _deletingPostId == post.id;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          post.fileType == 'video'
                              ? Icons.videocam_outlined
                              : Icons.audiotrack,
                        ),
                      ),
                      title: Text(
                        post.songTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${_formatTime(post.createdAt)} · '
                        'Skor ${post.score.toStringAsFixed(0)} · '
                        '${_commentsByPostId[post.id]?.length ?? 0} komentar',
                      ),
                      onTap: () => _showPostDetails(post),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Hapus lagu',
                            icon: isDeleting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                            onPressed: _deletingPostId != null
                                ? null
                                : () => _deletePost(post),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }
}
