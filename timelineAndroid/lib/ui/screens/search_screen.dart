import 'package:flutter/material.dart';
import '../../data/notes_repository.dart';

/// Screen for searching and filtering notes
class SearchScreen extends StatefulWidget {
  final String? initialSearchText;
  final List<String> initialTags;

  const SearchScreen({
    super.key,
    this.initialSearchText,
    this.initialTags = const [],
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _repository = NotesRepository();
  List<String> _allTags = [];
  List<String> _selectedTags = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialSearchText ?? '';
    _selectedTags = List.from(widget.initialTags);
    _loadTags();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    final tags = await _repository.getAllTags();
    setState(() {
      _allTags = tags;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search & Filter'),
        actions: [
          TextButton(
            onPressed: _apply,
            child: const Text('Apply'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search text
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search notes...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 24),

            // Tags section
            Text(
              'Filter by Tags',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_allTags.isEmpty)
              Text(
                'No tags found',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allTags.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text('#$tag'),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),

            const Spacer(),

            // Clear button
            if (_searchController.text.isNotEmpty || _selectedTags.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _clear,
                  child: const Text('Clear All Filters'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _apply() {
    Navigator.pop(context, {
      'searchText': _searchController.text.isEmpty ? null : _searchController.text,
      'tags': _selectedTags,
    });
  }

  void _clear() {
    setState(() {
      _searchController.clear();
      _selectedTags.clear();
    });
  }
}
