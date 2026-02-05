import 'dart:io';
import 'package:flutter/material.dart';

/// A grid displaying images with optional remove button
class ImageGrid extends StatelessWidget {
  final List<File> images;
  final void Function(int index)? onRemove;

  const ImageGrid({
    super.key,
    required this.images,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return _ImageTile(
            image: images[index],
            onRemove: onRemove != null ? () => onRemove!(index) : null,
          );
        },
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final File image;
  final VoidCallback? onRemove;

  const _ImageTile({
    required this.image,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            image,
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 120,
              height: 120,
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image),
            ),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
