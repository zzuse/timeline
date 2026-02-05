import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/note.dart';
import '../../data/notes_repository.dart';
import '../../services/sync_engine.dart';
import '../components/note_row.dart';
import 'compose_screen.dart';
import 'detail_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

/// Main timeline screen showing all notes
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  List<Note> _notes = [];
  bool _isLoading = true;
  String? _searchText;
  List<String> _selectedTags = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      final repository = context.read<NotesRepository>();
      List<Note> notes;
      if (_searchText != null || _selectedTags.isNotEmpty) {
        notes = await repository.searchNotes(
          searchText: _searchText,
          tags: _selectedTags.isNotEmpty ? _selectedTags : null,
        );
      } else {
        notes = await repository.getAllNotes();
      }
      if (mounted) {
        setState(() {
          _notes = notes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notes: $e')),
        );
      }
    }
  }

  List<Note> get _pinnedNotes => _notes.where((n) => n.isPinned).toList();
  List<Note> get _regularNotes => _notes.where((n) => !n.isPinned).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline'),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _openFilters,
              tooltip: 'Filter',
            ),
          ],
        ),
        leadingWidth: 56,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNote,
        child: const Icon(Icons.edit_note),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notes.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadNotes,
      child: ListView(
        children: [
          // Filter indicator
          if (_searchText != null || _selectedTags.isNotEmpty)
            _buildFilterIndicator(),

          // Pinned section
          if (_pinnedNotes.isNotEmpty) ...[
            _buildSectionHeader('Pinned'),
            ..._pinnedNotes.map((note) => _buildNoteRow(note)),
          ],

          // All notes section
          _buildSectionHeader(_pinnedNotes.isEmpty ? 'Notes' : 'All'),
          if (_regularNotes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('No notes in this section'),
              ),
            )
          else
            ..._regularNotes.map((note) => _buildNoteRow(note)),
          
          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_add_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No Notes Yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first note to start the timeline.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _createNote,
            icon: const Icon(Icons.add),
            label: const Text('Create Note'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterIndicator() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_alt,
            size: 18,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Filtered${_searchText != null ? ': "$_searchText"' : ''}${_selectedTags.isNotEmpty ? ' • Tags: ${_selectedTags.join(", ")}' : ''}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _clearFilters,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildNoteRow(Note note) {
    return Dismissible(
      key: Key(note.id),
      background: _buildSwipeBackground(
        alignment: Alignment.centerLeft,
        color: Colors.blue,
        icon: Icons.push_pin,
        label: note.isPinned ? 'Unpin' : 'Pin',
      ),
      secondaryBackground: _buildSwipeBackground(
        alignment: Alignment.centerRight,
        color: Colors.red,
        icon: Icons.delete,
        label: 'Delete',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _togglePin(note);
          return false; // Don't dismiss, just toggle
        } else {
          return await _confirmDelete(note);
        }
      },
      child: NoteRow(
        note: note,
        onTap: () => _openDetail(note),
      ),
    );
  }

  Widget _buildSwipeBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignment == Alignment.centerRight) ...[
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
          ],
          Icon(icon, color: Colors.white),
          if (alignment == Alignment.centerLeft) ...[
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }

  Future<void> _togglePin(Note note) async {
    try {
      final repository = context.read<NotesRepository>();
      final syncEngine = context.read<SyncEngine>();
      
      final updatedNote = await repository.togglePin(note);
      
      // Queue for sync
      try {
        await syncEngine.queueNoteForSync(updatedNote, 'update');
      } catch (e) {
        print('Error queuing pin update for sync: $e');
      }
      
      _loadNotes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating note: $e')),
        );
      }
    }
  }

  Future<bool> _confirmDelete(Note note) async {
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
        
        // Queue for sync BEFORE deleting locally (capture state)
        try {
          await syncEngine.queueNoteForSync(note, 'delete');
        } catch (e) {
           print('Error queuing delete for sync: $e');
        }

        await repository.deleteNote(note);
        _loadNotes();
        return true;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting note: $e')),
          );
        }
      }
    }
    return false;
  }

  void _createNote() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ComposeScreen()),
    );
    if (result == true) {
      _loadNotes();
    }
  }

  void _openDetail(Note note) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(note: note)),
    );
    if (result == true) {
      _loadNotes();
    }
  }

  void _openFilters() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          initialSearchText: _searchText,
          initialTags: _selectedTags,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _searchText = result['searchText'] as String?;
        _selectedTags = List<String>.from(result['tags'] ?? []);
      });
      _loadNotes();
    }
  }

  void _clearFilters() {
    setState(() {
      _searchText = null;
      _selectedTags = [];
    });
    _loadNotes();
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }
}
