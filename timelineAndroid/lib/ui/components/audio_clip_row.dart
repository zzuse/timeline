import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../data/audio_store.dart';

/// A row displaying an audio clip with play/stop functionality
class AudioClipRow extends StatefulWidget {
  final String title;
  final String audioPath;
  final VoidCallback? onDelete;

  const AudioClipRow({
    super.key,
    required this.title,
    required this.audioPath,
    this.onDelete,
  });

  @override
  State<AudioClipRow> createState() => _AudioClipRowState();
}

class _AudioClipRowState extends State<AudioClipRow> {
  final AudioPlayer _player = AudioPlayer();
  final AudioStore _audioStore = AudioStore();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _player.stop();
      setState(() => _isPlaying = false);
    } else {
      try {
        final path = await _audioStore.getAudioPath(widget.audioPath);
        await _player.play(DeviceFileSource(path));
        setState(() => _isPlaying = true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to play audio')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.audio_file,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.stop_circle : Icons.play_circle,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: _togglePlayback,
          ),
          if (widget.onDelete != null)
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: widget.onDelete,
            ),
        ],
      ),
    );
  }
}
