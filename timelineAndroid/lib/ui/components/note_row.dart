import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../models/note.dart';
import '../../data/image_store.dart';

/// A row displaying a note in the timeline list
class NoteRow extends StatelessWidget {
  final Note note;
  final VoidCallback? onTap;

  const NoteRow({
    super.key,
    required this.note,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image preview
              if (note.imagePaths.isNotEmpty) _buildImagePreview(),

              // Text content
              if (note.text.isNotEmpty) ...[
                if (note.imagePaths.isNotEmpty) const SizedBox(height: 8),
                Text(
                  note.text,
                  style: theme.textTheme.bodyLarge,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Tags
              if (note.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: note.tags.map((tag) => _TagChip(tag: tag)).toList(),
                ),
              ],

              // Audio indicator
              if (note.audioPaths.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.audio_file,
                      size: 16,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${note.audioPaths.length} audio clip${note.audioPaths.length == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ],

              // Timestamp
              const SizedBox(height: 8),
              Row(
                children: [
                  if (note.isPinned) ...[
                    Icon(
                      Icons.push_pin,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    _formatDate(note.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return FutureBuilder<String>(
      future: ImageStore().getImagePath(note.imagePaths.first),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(snapshot.data!),
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 160,
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image, size: 48),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat.MMMd().add_jm().format(date);
  }
}

class _TagChip extends StatelessWidget {
  final String tag;

  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '#$tag',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
