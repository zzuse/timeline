import 'dart:io';
import 'package:meta/meta.dart';
import '../models/note.dart';
import 'database_helper.dart';
import 'image_store.dart';
import 'audio_store.dart';

/// Repository for managing notes with media files
class NotesRepository {
  final DatabaseHelper _db;
  final ImageStore _imageStore;
  final AudioStore _audioStore;

  static final NotesRepository _instance = NotesRepository._internal();

  factory NotesRepository() {
    return _instance;
  }

  NotesRepository._internal({
    DatabaseHelper? db,
    ImageStore? imageStore,
    AudioStore? audioStore,
  })  : _db = db ?? DatabaseHelper.instance,
        _imageStore = imageStore ?? ImageStore(),
        _audioStore = audioStore ?? AudioStore();
        
  @visibleForTesting
  factory NotesRepository.test({
    DatabaseHelper? db,
    ImageStore? imageStore,
    AudioStore? audioStore,
  }) {
    return NotesRepository._internal(
      db: db,
      imageStore: imageStore,
      audioStore: audioStore,
    );
  }

  ImageStore get imageStore => _imageStore;
  AudioStore get audioStore => _audioStore;

  /// Create a new note with images
  Future<Note> createNote({
    required String text,
    List<File> images = const [],
    List<String> audioPaths = const [],
    List<String> tags = const [],
  }) async {
    // Save images and get filenames
    final List<String> imageFilenames = [];
    for (final image in images) {
      final filename = await _imageStore.saveImage(image);
      imageFilenames.add(filename);
    }

    // Normalize tags
    final normalizedTags = tags
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();

    final note = Note.create(
      text: text,
      imagePaths: imageFilenames,
      audioPaths: audioPaths,
      tags: normalizedTags,
    );

    await _db.insertNote(note);
    return note;
  }

  /// Update an existing note
  Future<Note> updateNote({
    required Note note,
    String? text,
    List<File>? newImages,
    List<String>? imagePaths,
    List<String>? audioPaths,
    List<String>? tags,
    bool? isPinned,
  }) async {
    List<String> finalImagePaths = imagePaths ?? note.imagePaths;

    // Add new images if provided
    if (newImages != null && newImages.isNotEmpty) {
      for (final image in newImages) {
        final filename = await _imageStore.saveImage(image);
        finalImagePaths = [...finalImagePaths, filename];
      }
    }

    // Normalize tags if provided
    List<String>? normalizedTags;
    if (tags != null) {
      normalizedTags = tags
          .map((t) => t.trim().toLowerCase())
          .where((t) => t.isNotEmpty)
          .toSet()
          .toList();
    }

    final updatedNote = note.copyWith(
      text: text,
      updatedAt: DateTime.now(),
      isPinned: isPinned,
      imagePaths: finalImagePaths,
      audioPaths: audioPaths,
      tags: normalizedTags,
    );

    await _db.updateNote(updatedNote);
    return updatedNote;
  }

  /// Toggle pin status
  Future<Note> togglePin(Note note) async {
    return updateNote(note: note, isPinned: !note.isPinned);
  }

  /// Delete a note and its media files
  Future<void> deleteNote(Note note) async {
    // Delete associated media files
    await _imageStore.deleteImages(note.imagePaths);
    await _audioStore.deleteAudios(note.audioPaths);

    // Delete from database
    await _db.deleteNote(note.id);
  }

  /// Get all notes sorted by pinned status and date
  Future<List<Note>> getAllNotes() async {
    return _db.getAllNotes();
  }

  /// Search notes by text and/or tags
  Future<List<Note>> searchNotes({String? searchText, List<String>? tags}) async {
    return _db.searchNotes(searchText: searchText, tags: tags);
  }

  /// Get all unique tags
  Future<List<String>> getAllTags() async {
    return _db.getAllTags();
  }

  /// Get a single note by ID
  Future<Note?> getNote(String id) async {
    return _db.getNote(id);
  }

  /// Get image file path
  Future<String> getImagePath(String filename) async {
    return _imageStore.getImagePath(filename);
  }

  /// Get audio file path
  Future<String> getAudioPath(String filename) async {
    return _audioStore.getAudioPath(filename);
  }

  /// Get all dirty (unsynced) notes
  Future<List<Note>> getDirtyNotes() async {
    final db = await _db.database;
    final result = await db.query(
      'notes',
      where: 'isDirty = ?',
      whereArgs: [1],
    );
    return result.map((map) => Note.fromMap(map)).toList();
  }

  /// Create note from existing Note object (for sync)
  Future<void> insertNoteForSync(Note note) async {
    await _db.insertNote(note);
  }

  /// Update note directly (for sync)
  Future<void> updateNoteForSync(Note note) async {
    await _db.updateNote(note);
  }

  /// Delete note by ID (for sync)
  Future<void> deleteNoteById(String id) async {
    final note = await getNote(id);
    if (note != null) {
      await _imageStore.deleteImages(note.imagePaths);
      await _audioStore.deleteAudios(note.audioPaths);
    }
    await _db.deleteNote(id);
  }
}
