import 'package:flutter/material.dart';

/// A tag input field with chip display and add functionality
class TagInputField extends StatefulWidget {
  final List<String> tags;
  final ValueChanged<List<String>> onTagsChanged;
  final List<String>? suggestions;

  const TagInputField({
    super.key,
    required this.tags,
    required this.onTagsChanged,
    this.suggestions,
  });

  @override
  State<TagInputField> createState() => _TagInputFieldState();
}

class _TagInputFieldState extends State<TagInputField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final normalized = tag.trim().toLowerCase();
    if (normalized.isNotEmpty && !widget.tags.contains(normalized)) {
      widget.onTagsChanged([...widget.tags, normalized]);
    }
    _controller.clear();
  }

  void _removeTag(String tag) {
    widget.onTagsChanged(widget.tags.where((t) => t != tag).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Existing tags
        if (widget.tags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.tags.map((tag) {
              return Chip(
                label: Text('#$tag'),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () => _removeTag(tag),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // Input field
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Add a tag...',
            prefixIcon: const Icon(Icons.tag),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                if (_controller.text.isNotEmpty) {
                  _addTag(_controller.text);
                }
              },
            ),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              _addTag(value);
              _focusNode.requestFocus();
            }
          },
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }
}
