import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/song_post.dart';

class UploadScoringPage extends StatefulWidget {
  const UploadScoringPage({super.key});

  @override
  State<UploadScoringPage> createState() => _UploadScoringPageState();
}

class _UploadScoringPageState extends State<UploadScoringPage> {
  static const String _bucketName = 'song-uploads';
  static const String _tableName = 'song_posts';

  final SupabaseClient _supabase = Supabase.instance.client;
  final AudioPlayer _player = AudioPlayer();

  List<SongPost> _posts = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String? _playingPostId;

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

      setState(() {
        _posts = (data as List)
            .map((row) => SongPost.fromMap(row as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat daftar: $e')),
        );
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
    if (result == null || result.files.isEmpty) return;

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
    final String fileType = extension == 'mp4' ? 'video' : 'audio';
    final String storagePath =
        '${DateTime.now().millisecondsSinceEpoch}_${picked.name}';

    setState(() => _isUploading = true);
    try {
      await _supabase.storage.from(_bucketName).uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: fileType == 'video' ? 'video/mp4' : 'audio/mpeg',
            ),
          );

      final String publicUrl =
          _supabase.storage.from(_bucketName).getPublicUrl(storagePath);

      await _supabase.from(_tableName).insert({
        'file_name': picked.name,
        'file_url': publicUrl,
        'file_type': fileType,
      });

      await _loadPosts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal upload: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
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
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
                      final bool isPlaying = _playingPostId == post.id;
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
                            post.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(_formatTime(post.createdAt)),
                          trailing: IconButton(
                            icon: Icon(
                              isPlaying
                                  ? Icons.stop_circle
                                  : Icons.play_circle_fill,
                              size: 32,
                            ),
                            onPressed: () => _togglePlay(post),
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