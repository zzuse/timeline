import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../models/note.dart';
import '../../data/notes_repository.dart';
import '../../data/image_store.dart';
import '../../services/sync_engine.dart';
import '../components/tag_input_field.dart';
import '../components/image_grid.dart';

/// Screen for editing an existing note
class EditScreen extends StatefulWidget {
  final Note note;

  const EditScreen({super.key, required this.note});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final _textController = TextEditingController();
  final _imageStore = ImageStore();
  final _imagePicker = ImagePicker();

  List<File> _existingImages = [];
  List<String> _existingImageFilenames = [];
  List<File> _newImages = [];
  List<String> _tags = [];
  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _textController.text = widget.note.text;
    _tags = List.from(widget.note.tags);
    _loadImages();
  }

  Future<void> _loadImages() async {
    final files = <File>[];
    for (final filename in widget.note.imagePaths) {
      final file = await _imageStore.loadImage(filename);
      if (file != null) {
        files.add(file);
      }
    }
    setState(() {
      _existingImages = files;
      _existingImageFilenames = List.from(widget.note.imagePaths);
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  List<File> get _allImages => [..._existingImages, ..._newImages];

  bool get _canSave =>
      _textController.text.trim().isNotEmpty ||
      _allImages.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Note')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Note'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _canSave && !_isSaving ? _save : null,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text input
            _buildSectionHeader('Note'),
            TextField(
              controller: _textController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'What\'s on your mind?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 24),

            // Photos section
            _buildSectionHeader('Photos'),
            if (_allImages.isNotEmpty) ...[
              ImageGrid(
                images: _allImages,
                onRemove: _removeImage,
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Tags section
            _buildSectionHeader('Tags'),
            TagInputField(
              tags: _tags,
              onTagsChanged: (tags) => setState(() => _tags = tags),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _removeImage(int index) {
    setState(() {
      if (index < _existingImages.length) {
        _existingImages.removeAt(index);
        _existingImageFilenames.removeAt(index);
      } else {
        _newImages.removeAt(index - _existingImages.length);
      }
    });
  }

  Future<void> _pickImages() async {
    try {
      final images = await _imagePicker.pickMultiImage(
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (images.isNotEmpty) {
        setState(() {
          _newImages.addAll(images.map((x) => File(x.path)));
        });
      }
    } catch (e) {
      _showError('Failed to pick images');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        _showError('Camera permission required');
        return;
      }

      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _newImages.add(File(image.path));
        });
      }
    } catch (e) {
      _showError('Failed to take photo');
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final repository = context.read<NotesRepository>();
      final syncEngine = context.read<SyncEngine>();
      
      final updated = await repository.updateNote(
        note: widget.note,
        text: _textController.text.trim(),
        newImages: _newImages,
        imagePaths: _existingImageFilenames,
        audioPaths: widget.note.audioPaths, // Keep existing audio
        tags: _tags,
      );
      
      // Queue for sync
      try {
        await syncEngine.queueNoteForSync(updated, 'update');
      } catch (e) {
        print('Error queuing update for sync: $e');
      }
      
      if (mounted) {
        Navigator.pop(context, updated);
      }
    } catch (e) {
      _showError('Failed to save note');
      setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}
