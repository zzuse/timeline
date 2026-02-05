/// Centralized mock definitions for test suite
///
/// This file provides manual mocks for all services and data layer components.
/// Manual mocks are used instead of mockito's @GenerateMocks to avoid
/// build_runner dependency issues.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:timeline/models/note.dart';
import 'package:timeline/data/notes_repository.dart';
import 'package:timeline/data/image_store.dart';
import 'package:timeline/data/audio_store.dart';
import 'package:timeline/services/auth_session_manager.dart';
import 'package:timeline/services/sync_queue.dart';
import 'package:timeline/services/sync_engine.dart';
import 'package:timeline/services/notesync_client.dart';
import 'package:http/http.dart' as http;

// ============================================================================
// MockNotesRepository
// ============================================================================

class MockNotesRepository implements NotesRepository {
  final List<Note> _notes = [];
  Note? _lastCreatedNote;
  Note? _lastUpdatedNote;
  String? _lastDeletedNoteId;
  
  final _imageStore = MockImageStore();
  final _audioStore = MockAudioStore();

  @override
  ImageStore get imageStore => _imageStore;
  
  @override
  AudioStore get audioStore => _audioStore;

  @override
  Future<List<Note>> getDirtyNotes() async {
    return _notes.where((n) => n.isDirty).toList();
  }
  
  // Test helpers
  void addNote(Note note) => _notes.add(note);
  void clearNotes() => _notes.clear();
  Note? get lastCreatedNote => _lastCreatedNote;
  Note? get lastUpdatedNote => _lastUpdatedNote;
  String? get lastDeletedNoteId => _lastDeletedNoteId;
  
  @override
  Future<List<Note>> getAllNotes() async => List.from(_notes);
  
  @override
  Future<Note?> getNote(String id) async {
    try {
      return _notes.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }
  
  @override
  Future<Note> createNote({
    required String text,
    List<File> images = const [],
    List<String> audioPaths = const [],
    List<String> tags = const [],
  }) async {
    final note = Note.create(text: text, tags: tags, audioPaths: audioPaths);
    _notes.add(note);
    _lastCreatedNote = note;
    return note;
  }
  
  @override
  Future<Note> updateNote({
    required Note note,
    String? text,
    List<File>? newImages,
    List<String>? imagePaths,
    List<String>? audioPaths,
    List<String>? tags,
    bool? isPinned,
  }) async {
    final updated = note.copyWith(
      text: text,
      imagePaths: imagePaths,
      audioPaths: audioPaths,
      tags: tags,
      isPinned: isPinned,
    );
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index >= 0) {
      _notes[index] = updated;
    }
    _lastUpdatedNote = updated;
    return updated;
  }

  @override
  Future<Note> togglePin(Note note) async {
    final updated = note.copyWith(isPinned: !note.isPinned);
    await updateNote(note: updated, isPinned: updated.isPinned);
    return updated;
  }
  
  @override
  Future<void> deleteNote(Note note) async {
    _notes.removeWhere((n) => n.id == note.id);
    _lastDeletedNoteId = note.id;
  }
  
  @override
  Future<List<Note>> searchNotes({String? searchText, List<String>? tags}) async {
    return _notes.where((note) {
      final matchesText = searchText == null || searchText.isEmpty || note.text.contains(searchText);
      final matchesTags = tags == null || tags.isEmpty || 
          tags.any((tag) => note.tags.contains(tag));
      return matchesText && matchesTags;
    }).toList();
  }
  
  @override
  Future<List<String>> getAllTags() async {
    final tags = <String>{};
    for (final note in _notes) {
      tags.addAll(note.tags);
    }
    return tags.toList();
  }
  
  @override
  Future<void> insertNoteForSync(Note note) async {
     _notes.add(note);
     _lastCreatedNote = note;
  }

  @override
  Future<void> updateNoteForSync(Note note) async {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index >= 0) {
      _notes[index] = note;
    }
    _lastUpdatedNote = note;
  }

  @override
  Future<void> deleteNoteById(String id) async {
    _notes.removeWhere((n) => n.id == id);
    _lastDeletedNoteId = id;
  }

  // Missing methods
  @override
  Future<String> getImagePath(String filename) async => '';
  
  @override
  Future<String> getAudioPath(String filename) async => '';
}

// ============================================================================
// MockImageStore
// ============================================================================

class MockImageStore implements ImageStore {
  final Map<String, List<int>> _images = {};
  
  // Test helpers
  void clearImages() => _images.clear();
  bool hasImage(String filename) => _images.containsKey(filename);
  List<int>? getImageBytes(String filename) => _images[filename];
  void addImage(String filename, List<int> bytes) => _images[filename] = bytes;
  
  @override
  Future<String> getImagePath(String filename) async {
    // Assuming _images stores the content, and we need a path.
    // For a mock, we can return a dummy path.
    // The original instruction used `_files` which is not defined,
    // so we'll provide a sensible mock implementation based on existing fields.
    return _images.containsKey(filename) ? '/tmp/$filename' : '';
  }

  @override
  Future<String> url({required String for_}) async {
    return '/tmp/$for_';
  }
  
  @override
  Future<void> init() async {}
  
  @override
  Future<String> saveImage(File imageFile) async {
    final filename = 'mock_${DateTime.now().millisecondsSinceEpoch}.jpg';
    _images[filename] = await imageFile.readAsBytes();
    return filename;
  }
  
  @override
  Future<String> saveImageBytes(List<int> bytes) async {
    final filename = 'mock_${DateTime.now().millisecondsSinceEpoch}.jpg';
    _images[filename] = bytes;
    return filename;
  }
  
  @override
  Future<File?> loadImage(String filename) async {
    if (!_images.containsKey(filename)) return null;
    // Return a temp file for testing
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(_images[filename]!);
    return file;
  }
  
  @override
  Future<void> deleteImages(List<String> filenames) async {
    for (final name in filenames) {
      _images.remove(name);
    }
  }
  
  @override
  Future<void> saveBytes(String filename, List<int> bytes) async {
    _images[filename] = bytes;
  }
  
  @override
  Future<File> getFile(String filename) async {
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/$filename');
    if (_images.containsKey(filename)) {
      await file.writeAsBytes(_images[filename]!);
    }
    return file;
  }
}

// ============================================================================
// MockAudioStore
// ============================================================================

class MockAudioStore implements AudioStore {
  final Map<String, List<int>> _audio = {};
  
  // Test helpers
  void addAudio(String filename, List<int> bytes) => _audio[filename] = bytes;
  void clearAudio() => _audio.clear();
  bool hasAudio(String filename) => _audio.containsKey(filename);
  
  @override
  Future<void> init() async {}
  
  @override
  Future<String> createRecordingPath() async {
    return 'mock_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }
  
  @override
  Future<void> deleteAudio(List<String> filenames) async {
    for (final name in filenames) {
      _audio.remove(name);
    }
  }
  
  @override
  Future<String> getAudioPath(String filename) async {
    if (!_audio.containsKey(filename)) return '';
    return '/mock/path/$filename';
  }
  
  @override
  Future<void> saveBytes(String filename, List<int> bytes) async {
    _audio[filename] = bytes;
  }

  @override
  Future<bool> audioExists(String filename) async {
    return _audio.containsKey(filename);
  }

  @override
  Future<void> deleteAudios(List<String> filenames) async {
    for (final filename in filenames) {
      _audio.remove(filename);
    }
  }

  @override
  Future<({String path, String filename})> makeRecordingPath() async {
    final filename = 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
    return (path: '/tmp/$filename', filename: filename);
  }

  @override
  Future<String> url({required String for_}) async {
    return '/tmp/$for_';
  }
  
  @override
  Future<File> getFile(String filename) async {
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/$filename');
    if (_audio.containsKey(filename)) {
      await file.writeAsBytes(_audio[filename]!);
    }
    return file;
  }
}

// ============================================================================
// MockAuthSessionManager
// ============================================================================

class MockAuthSessionManager extends ChangeNotifier implements AuthSessionManager {
  String? _accessToken;
  bool _shouldRefreshSucceed = true;
  AuthState _state = AuthState.signedOut;
  String? _errorMessage;
  
  // Test helpers
  void setAccessToken(String? token) {
    _accessToken = token;
    _state = token != null ? AuthState.signedIn : AuthState.signedOut;
  }
  void setRefreshSuccess(bool success) => _shouldRefreshSucceed = success;
  void setState(AuthState state) => _state = state;
  
  @override
  AuthState get state => _state;
  
  @override
  String? get errorMessage => _errorMessage;
  
  @override
  bool get isSignedIn => _state == AuthState.signedIn;
  
  @override
  Future<String?> getAccessToken() async => _accessToken;
  
  @override
  Future<String?> getRefreshToken() async => null;
  
  @override
  Future<bool> refreshAccessToken() async {
    if (_shouldRefreshSucceed) {
      _accessToken = 'refreshed-token';
      return true;
    }
    return false;
  }
  
  @override
  Future<void> clearSession() async {
    _accessToken = null;
    _state = AuthState.signedOut;
  }
  
  @override
  Future<bool> hasValidSession() async => _accessToken != null;
  
  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    _accessToken = accessToken;
    _state = AuthState.signedIn;
  }
  
  @override
  Future<void> login() async {}
  
  @override
  Future<void> signOut() async {
    await clearSession();
  }
  
  @override
  Future<bool> handleCallback(Uri callbackUri) async => true;
  
  @override
  Future<bool> exchangeCodeForTokens(String code) async => true;
  
  @override
  void clearError() {
    _errorMessage = null;
  }
}

// ============================================================================
// MockSyncQueue
// ============================================================================

class MockSyncQueue implements SyncQueue {
  final List<SyncQueueItem> _items = [];
  final Map<String, File> _mediaFiles = {};
  
  // Test helpers
  void addItem(SyncQueueItem item) => _items.add(item);
  void clearItems() => _items.clear();
  int get itemCount => _items.length;
  void registerMediaFile(String filename, File file) => _mediaFiles[filename] = file;
  
  @override
  Future<void> init() async {}
  
  @override
  Future<void> enqueueCreate(Note note, List<String> imagePaths, List<String> audioPaths) async {
    _items.add(SyncQueueItem(
      opId: 'mock-op-${DateTime.now().millisecondsSinceEpoch}',
      opType: 'create',
      note: SyncQueuedNote(
        id: note.id,
        text: note.text,
        isPinned: note.isPinned,
        tags: note.tags,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
      ),
      media: [],
    ));
  }
  
  @override
  Future<void> enqueueUpdate(Note note, List<String> imagePaths, List<String> audioPaths) async {
    _items.add(SyncQueueItem(
      opId: 'mock-op-${DateTime.now().millisecondsSinceEpoch}',
      opType: 'update',
      note: SyncQueuedNote(
        id: note.id,
        text: note.text,
        isPinned: note.isPinned,
        tags: note.tags,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
      ),
      media: [],
    ));
  }
  
  @override
  Future<void> enqueueDelete(Note note) async {
    _items.add(SyncQueueItem(
      opId: 'mock-op-${DateTime.now().millisecondsSinceEpoch}',
      opType: 'delete',
      note: SyncQueuedNote(
        id: note.id,
        text: note.text,
        isPinned: note.isPinned,
        tags: note.tags,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
        deletedAt: DateTime.now(),
      ),
      media: [],
    ));
  }
  
  @override
  Future<List<SyncQueueItem>> pending() async => List.from(_items);
  
  @override
  Future<void> remove(List<SyncQueueItem> items) async {
    for (final item in items) {
      _items.removeWhere((i) => i.opId == item.opId);
    }
  }
  
  @override
  Future<int> pendingCount() async => _items.length;
  
  @override
  File getMediaFile(SyncQueuedMedia media) {
    return _mediaFiles[media.filename] ?? File('/tmp/${media.filename}'); // SyncQueue expects synchronous File return
  }
  
  // Missing helper for interface
  @override
  Future<void> initialize() async {}
}

// ============================================================================
// MockNotesyncClient
// ============================================================================

class MockNotesyncClient implements NotesyncClient {
  SyncResponse? _syncResponse;
  NotesyncRestoreResponse? _fetchResponse;
  bool _shouldSucceed = true;
  Exception? _exceptionToThrow;
  
  @override
  final AuthSessionManager authManager = MockAuthSessionManager();
  
  @override
  final http.Client httpClient = http.Client(); // Dummy client

  @override
  void dispose() {}
  
  // Test helpers
  void setSyncResponse(SyncResponse response) => _syncResponse = response;
  void setFetchResponse(NotesyncRestoreResponse response) => _fetchResponse = response;
  void setShouldSucceed(bool value) => _shouldSucceed = value;
  void setExceptionToThrow(Exception? e) => _exceptionToThrow = e;
  
  SyncRequest? lastSyncRequest;
  
  @override
  Future<SyncResponse> sendSync(SyncRequest request) async {
    lastSyncRequest = request;
    if (_exceptionToThrow != null) throw _exceptionToThrow!;
    if (!_shouldSucceed) throw Exception('Mock sync failed');
    return _syncResponse ?? SyncResponse(results: []);
  }
  
  @override
  Future<NotesyncRestoreResponse> fetchLatestNotes({int limit = 100}) async {
    if (_exceptionToThrow != null) throw _exceptionToThrow!;
    if (!_shouldSucceed) throw Exception('Mock fetch failed');
    return _fetchResponse ?? NotesyncRestoreResponse(notes: [], media: []);
  }
}

// ============================================================================
// MockSyncEngine
// ============================================================================

class MockSyncEngine extends ChangeNotifier implements SyncEngine {
  SyncStatus _status = SyncStatus.idle;
  
  @override
  final AuthSessionManager authManager = MockAuthSessionManager();
  
  @override
  final NotesRepository repository = MockNotesRepository();
  
  @override
  final NotesyncClient syncClient = MockNotesyncClient();
  
  @override
  final SyncQueue syncQueue = MockSyncQueue();

  @override
  String? get errorMessage => null;
  
  @override
  int get syncProgress => 0;
  DateTime? _lastSyncTime;
  String? _errorMessage;
  double _progress = 0.0;
  
  final List<Note> _queuedNotes = [];
  final List<String> _queuedOperations = [];
  
  // Test helpers
  void setStatus(SyncStatus status) {
    _status = status;
    notifyListeners();
  }
  void setLastSyncTime(DateTime? time) => _lastSyncTime = time;
  void setErrorMessage(String? message) => _errorMessage = message;
  List<Note> get queuedNotes => _queuedNotes;
  List<String> get queuedOperations => _queuedOperations;
  
  @override
  SyncStatus get status => _status;
  
  @override
  DateTime? get lastSyncTime => _lastSyncTime;
  
  @override
  String? get error => _errorMessage;
  
  @override
  double get progress => _progress;
  
  @override
  Future<void> init() async {}
  
  @override
  Future<void> sync() async {
    _status = SyncStatus.syncing;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 100));
    _status = SyncStatus.idle;
    _lastSyncTime = DateTime.now();
    notifyListeners();
  }
  
  @override
  Future<void> queueNoteForSync(Note note, String operation) async {
    _queuedNotes.add(note);
    _queuedOperations.add(operation);
  }
  
  @override
  Future<void> fullResync() async {
    _status = SyncStatus.syncing;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 100));
    _status = SyncStatus.idle;
    _lastSyncTime = DateTime.now();
    notifyListeners();
  }
  
  @override
  void dispose() {
    super.dispose();
  }
}
