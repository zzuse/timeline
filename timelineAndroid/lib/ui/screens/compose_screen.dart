import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../data/notes_repository.dart';
import '../../services/sync_engine.dart';
import '../components/tag_input_field.dart';
import '../components/image_grid.dart';

/// Screen for creating a new note
class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _textController = TextEditingController();
  final _imagePicker = ImagePicker();

  List<File> _selectedImages = [];
  List<String> _tags = [];
  bool _isSaving = false;

  bool get _canSave =>
      _textController.text.trim().isNotEmpty ||
      _selectedImages.isNotEmpty;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Note'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
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
            if (_selectedImages.isNotEmpty) ...[
              ImageGrid(
                images: _selectedImages,
                onRemove: (index) {
                  setState(() => _selectedImages.removeAt(index));
                },
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

            // Audio section (disabled)
            _buildSectionHeader('Audio'),
            Text(
              'Audio recording coming soon',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
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

  Future<void> _pickImages() async {
    try {
      final images = await _imagePicker.pickMultiImage(
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images.map((x) => File(x.path)));
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
          _selectedImages.add(File(image.path));
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

      final note = await repository.createNote(
        text: _textController.text.trim(),
        images: _selectedImages,
        audioPaths: [], // Audio disabled for now
        tags: _tags,
      );
      
      // Queue for sync
      try {
        await syncEngine.queueNoteForSync(note, 'create');
      } catch (e) {
        print('Error queuing note for sync: $e');
        // Continue even if sync queue fails, note is saved locally
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('Failed to save note: $e');
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
