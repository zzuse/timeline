import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/note.dart';
import '../../data/notes_repository.dart';
import '../../data/image_store.dart';
import '../../services/sync_engine.dart';
import 'edit_screen.dart';
import '../components/audio_clip_row.dart';

/// Screen for viewing note details
class DetailScreen extends StatefulWidget {
  final Note note;

  const DetailScreen({super.key, required this.note});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final _imageStore = ImageStore();
  late Note _note;
  List<String> _imagePaths = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _note = widget.note;
    _loadImages();
  }

  Future<void> _loadImages() async {
    final paths = <String>[];
    for (final filename in _note.imagePaths) {
      final path = await _imageStore.getImagePath(filename);
      paths.add(path);
    }
    setState(() {
      _imagePaths = paths;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Note'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _edit,
            tooltip: 'Edit',
          ),
          IconButton(
            icon: Icon(_note.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
            onPressed: _togglePin,
            tooltip: _note.isPinned ? 'Unpin' : 'Pin',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
            tooltip: 'Delete',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Images
                  if (_imagePaths.isNotEmpty) ...[
                    SizedBox(
                      height: 240,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _imagePaths.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_imagePaths[index]),
                              height: 240,
                              fit: BoxFit.cover,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Text
                  if (_note.text.isNotEmpty) ...[
                    Text(
                      _note.text,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Audio clips
                  if (_note.audioPaths.isNotEmpty) ...[
                    Text(
                      'Audio',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._note.audioPaths.asMap().entries.map((entry) {
                      return AudioClipRow(
                        title: 'Recording ${entry.key + 1}',
                        audioPath: entry.value,
                      );
                    }),
                    const SizedBox(height: 16),
                  ],

                  // Tags
                  if (_note.tags.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _note.tags.map((tag) {
                        return Chip(
                          label: Text('#$tag'),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Timestamps
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Created ${_formatDate(_note.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Updated ${_formatDate(_note.updatedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat.yMMMd().add_jm().format(date);
  }

  Future<void> _edit() async {
    final result = await Navigator.push<Note>(
      context,
      MaterialPageRoute(builder: (_) => EditScreen(note: _note)),
    );
    if (result != null) {
      setState(() => _note = result);
      _loadImages();
    }
  }

  Future<void> _togglePin() async {
    try {
      final repository = context.read<NotesRepository>();
      final syncEngine = context.read<SyncEngine>();
      
      final updated = await repository.togglePin(_note);
      
      // Queue for sync
      try {
        await syncEngine.queueNoteForSync(updated, 'update');
      } catch (e) {
        print('Error queuing pin update for sync: $e');
      }
      
      setState(() => _note = updated);
    } catch (e) {
      _showError('Failed to update pin status');
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repository = context.read<NotesRepository>();
        final syncEngine = context.read<SyncEngine>();
        
        // Queue for sync
        try {
          await syncEngine.queueNoteForSync(_note, 'delete');
        } catch (e) {
           print('Error queuing delete for sync: $e');
        }
        
        await repository.deleteNote(_note);
        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        _showError('Failed to delete note');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
