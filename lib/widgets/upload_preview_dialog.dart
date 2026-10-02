import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class UploadPreviewDialog extends StatefulWidget {
  final PlatformFile file;
  final Uint8List bytes;

  const UploadPreviewDialog({
    super.key,
    required this.file,
    required this.bytes,
  });

  @override
  State<UploadPreviewDialog> createState() => _UploadPreviewDialogState();
}

class _UploadPreviewDialogState extends State<UploadPreviewDialog> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  VideoPlayerController? _videoController;
  Future<void>? _videoInitialization;
  StreamSubscription<void>? _audioCompleteSubscription;
  final TextEditingController _titleController = TextEditingController();
  bool _isAudioPlaying = false;
  bool _isPreviewPlaying = false;
  bool _isTitleValid = false;

  bool get _isVideo => widget.file.extension?.toLowerCase() == 'mp4';

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.file.name.replaceFirst(
      RegExp(r'\.[^.]+$'),
      '',
    );
    _isTitleValid = _titleController.text.trim().isNotEmpty;
    _titleController.addListener(_onTitleChanged);
    if (_isVideo) {
      final videoUri = Uri.dataFromBytes(widget.bytes, mimeType: 'video/mp4');
      _videoController = VideoPlayerController.networkUrl(videoUri)
        ..addListener(_onVideoChanged);
      _videoInitialization = _videoController!.initialize();
      _videoInitialization!.then(
        (_) {
          if (mounted) setState(() {});
        },
        onError: (Object error, StackTrace stackTrace) {
          if (mounted) setState(() {});
        },
      );
    } else {
      _audioCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _isAudioPlaying = false);
      });
    }
  }

  void _onTitleChanged() {
    final isValid = _titleController.text.trim().isNotEmpty;
    if (isValid != _isTitleValid && mounted) {
      setState(() => _isTitleValid = isValid);
    }
  }

  void _onVideoChanged() {
    if (!mounted) return;
    final isPlaying = _videoController?.value.isPlaying ?? false;
    if (isPlaying != _isPreviewPlaying) {
      setState(() => _isPreviewPlaying = isPlaying);
    }
  }

  Future<void> _togglePreview() async {
    if (_isVideo) {
      final controller = _videoController;
      if (controller == null || !controller.value.isInitialized) return;
      if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        if (controller.value.position >= controller.value.duration) {
          await controller.seekTo(Duration.zero);
        }
        await controller.play();
      }
      return;
    }

    if (_isAudioPlaying) {
      await _audioPlayer.pause();
      if (mounted) setState(() => _isAudioPlaying = false);
    } else {
      await _audioPlayer.play(BytesSource(widget.bytes));
      if (mounted) setState(() => _isAudioPlaying = true);
    }
  }

  @override
  void dispose() {
    _audioCompleteSubscription?.cancel();
    unawaited(_audioPlayer.dispose());
    _videoController?.removeListener(_onVideoChanged);
    unawaited(_videoController?.dispose());
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoController = _videoController;
    return AlertDialog(
      title: const Text('Preview post lagu'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isVideo)
                _buildVideoPreview(videoController)
              else
                _buildAudioPreview(),
              const SizedBox(height: 12),
              Text(
                '${widget.file.name} · ${_formatBytes(widget.bytes.length)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                autofocus: true,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Judul lagu',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: !_isTitleValid
              ? null
              : () => Navigator.of(context).pop(_titleController.text.trim()),
          child: const Text('Upload post'),
        ),
      ],
    );
  }

  Widget _buildAudioPreview() {
    return Container(
      height: 112,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.audio_file, size: 40),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: _togglePreview,
            icon: Icon(_isAudioPlaying ? Icons.pause : Icons.play_arrow),
            label: Text(_isAudioPlaying ? 'Jeda preview' : 'Putar preview'),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview(VideoPlayerController? controller) {
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<void>(
      future: _videoInitialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            height: 180,
            alignment: Alignment.center,
            child: Text('Preview video gagal dibuka: ${snapshot.error}'),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return Column(
          children: [
            AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
            VideoProgressIndicator(controller, allowScrubbing: true),
            IconButton(
              tooltip: _isPreviewPlaying ? 'Jeda preview' : 'Putar preview',
              onPressed: _togglePreview,
              icon: Icon(
                _isPreviewPlaying ? Icons.pause_circle : Icons.play_circle,
                size: 36,
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
