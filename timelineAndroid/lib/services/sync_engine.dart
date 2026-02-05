import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../config/sync_config.dart';
import '../data/notes_repository.dart';
import '../models/note.dart';
import '../services/auth_session_manager.dart';
import '../services/notesync_client.dart';
import '../services/sync_queue.dart';
import '../services/media_utils.dart';

/// Sync status
enum SyncStatus {
  idle,
  syncing,
  success,
  error,
}

/// Orchestrates note synchronization
class SyncEngine extends ChangeNotifier {
  final NotesRepository repository;
  final AuthSessionManager authManager;
  final NotesyncClient syncClient;
  final SyncQueue syncQueue;

  SyncStatus _status = SyncStatus.idle;
  String? _errorMessage;
  DateTime? _lastSyncTime;
  int _syncProgress = 0; // 0-100
  Timer? _periodicSyncTimer;

  SyncStatus get status => _status;
  String? get errorMessage => _errorMessage;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get syncProgress => _syncProgress;

  SyncEngine({
    required this.repository,
    required this.authManager,
    required this.syncClient,
    required this.syncQueue,
  }) {
    _initialize();
  }

  Future<void> _initialize() async {
    await syncQueue.initialize();
    _startPeriodicSync();
  }

  /// Start periodic background sync
  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(SyncConfig.syncInterval, (timer) {
      if (authManager.isSignedIn) {
        sync();
      }
    });
  }

  /// Perform full sync cycle
  Future<void> sync() async {
    if (!authManager.isSignedIn) {
      _errorMessage = 'Not signed in';
      return;
    }

    if (_status == SyncStatus.syncing) {
      return; // Already syncing
    }

    try {
      _status = SyncStatus.syncing;
      _errorMessage = null;
      _syncProgress = 0;
      notifyListeners();

      // Check network connectivity
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        throw Exception('No network connection');
      }

      // Step 1: Push dirty local notes to server (40% of progress)
      await _pushDirtyNotes();
      _syncProgress = 40;
      notifyListeners();

      // Step 2: Process sync queue (30% of progress)
      await _processSyncQueue();
      _syncProgress = 70;
      notifyListeners();

      // Step 3: Pull latest changes from server (30% of progress)
      await _pullServerNotes();
      _syncProgress = 100;
      notifyListeners();

      _status = SyncStatus.success;
      _lastSyncTime = DateTime.now();
      _errorMessage = null;
    } catch (e) {
      _status = SyncStatus.error;
      _errorMessage = e.toString();
    } finally {
      _syncProgress = 0;
      notifyListeners();
    }
  }

  /// Push all dirty (modified) notes to server
  Future<void> _pushDirtyNotes() async {
    final dirtyNotes = await repository.getDirtyNotes();
    if (dirtyNotes.isEmpty) return;

    // Build sync operations
    final ops = dirtyNotes.map((note) {
      return SyncOperationPayload(
        opId: '${note.id}_${DateTime.now().millisecondsSinceEpoch}',
        opType: 'update',
        note: SyncNotePayload.fromNote(note),
      );
    }).toList();

    // Send to server
    final request = SyncRequest(ops: ops);
    final response = await syncClient.sendSync(request);

    // Update notes with server response
    for (final result in response.results) {
      final note = dirtyNotes.firstWhere((n) => n.id == result.noteId);
      final updatedNote = note.copyWith(
        serverId: result.noteId,
        lastSyncedAt: DateTime.now(),
        isDirty: false,
      );
      await repository.updateNoteForSync(updatedNote);
    }
  }

  /// Process items in sync queue
  Future<void> _processSyncQueue() async {
    print('SyncEngine: Checking for pending queue items...');
    final queueItems = await syncQueue.pending();
    print('SyncEngine: Found ${queueItems.length} pending items');
    
    if (queueItems.isEmpty) return;

    // Build sync operations from queue items
    final List<SyncOperationPayload> ops = [];

    for (final item in queueItems) {
      try {
        print('SyncEngine: Processing item ${item.opId} for note ${item.note.id}');
        
        // Build media payloads by encoding file data to base64
        final List<SyncMediaPayload> mediaPayloads = [];
        for (final queuedMedia in item.media) {
          print('SyncEngine: Processing media ${queuedMedia.filename} (${queuedMedia.kind})');
          final mediaFile = syncQueue.getMediaFile(queuedMedia);
          if (await mediaFile.exists()) {
            print('SyncEngine: File exists, encoding to base64...');
            final base64Data = await MediaUtils.encodeFileToBase64(mediaFile);
            mediaPayloads.add(SyncMediaPayload(
              id: queuedMedia.id,
              noteId: queuedMedia.noteId,
              kind: queuedMedia.kind,
              filename: queuedMedia.filename,
              contentType: queuedMedia.contentType,
              checksum: queuedMedia.checksum,
              dataBase64: base64Data,
            ));
            print('SyncEngine: Encoded media, size: ${base64Data.length}');
          } else {
            print('SyncEngine: ERROR - Media file not found at ${mediaFile.path}');
          }
        }

        // Build operation payload
        final notePayload = SyncNotePayload(
          id: item.note.id,
          text: item.note.text,
          isPinned: item.note.isPinned,
          tags: item.note.tags,
          createdAt: item.note.createdAt,
          updatedAt: item.note.updatedAt,
          deletedAt: item.note.deletedAt,
        );

        ops.add(SyncOperationPayload(
          opId: item.opId,
          opType: item.opType,
          note: notePayload,
          media: mediaPayloads,
        ));
      } catch (e) {
        print('Error building sync op for ${item.opId}: $e');
      }
    }

    if (ops.isEmpty) {
        print('SyncEngine: No operations built, aborting upload');
        return;
    }

    try {
      print('SyncEngine: Sending ${ops.length} operations to server...');
      // Send all operations to server
      final request = SyncRequest(ops: ops);
      await syncClient.sendSync(request);
      print('SyncEngine: Upload successful!');

      // Success - remove all items from queue
      await syncQueue.remove(queueItems);
      print('SyncEngine: Removed processed items from queue');
    } catch (e) {
      print('Sync queue upload failed: $e');
      // Don't remove items - will retry next sync
      rethrow;
    }
  }

  /// Pull latest notes from server and merge
  Future<void> _pullServerNotes() async {
    final response = await syncClient.fetchLatestNotes(limit: 100);

    // Save media files from server
    for (final serverMedia in response.media) {
      try {
        final bytes = MediaUtils.decodeBase64ToBytes(serverMedia.dataBase64);
        
        if (serverMedia.kind == 'image') {
          final imageStore = repository.imageStore;
          final filename = serverMedia.filename;
          await imageStore.saveBytes(filename, bytes);
        } else if (serverMedia.kind == 'audio') {
          final audioStore = repository.audioStore;
          final filename = serverMedia.filename;
          await audioStore.saveBytes(filename, bytes);
        }
      } catch (e) {
        print('Error saving media ${serverMedia.id}: $e');
      }
    }

    // Process notes
    for (final serverNote in response.notes) {
      final localNote = await repository.getNote(serverNote.id);

      if (localNote == null) {
        // New note from server - create locally
        // Get media paths for this note
        final notesMedia = response.media.where((m) => m.noteId == serverNote.id).toList();
        final imagePaths = notesMedia.where((m) => m.kind == 'image').map((m) => m.filename).toList();
        final audioPaths = notesMedia.where((m) => m.kind == 'audio').map((m) => m.filename).toList();
        
        final note = Note(
          id: serverNote.id,
          text: serverNote.text,
          createdAt: serverNote.createdAt,
          updatedAt: serverNote.updatedAt,
          isPinned: serverNote.isPinned,
          tags: serverNote.tags,
          imagePaths: imagePaths,
          audioPaths: audioPaths,
          serverId: serverNote.id,
          lastSyncedAt: DateTime.now(),
          isDirty: false,
        );
        await repository.insertNoteForSync(note);
      } else {
        // Existing note - resolve conflict
        final shouldUpdate = _shouldUseServerVersion(localNote, serverNote);
        if (shouldUpdate) {
          // Get media paths for this note
          final notesMedia = response.media.where((m) => m.noteId == serverNote.id).toList();
          final imagePaths = notesMedia.where((m) => m.kind == 'image').map((m) => m.filename).toList();
          final audioPaths = notesMedia.where((m) => m.kind == 'audio').map((m) => m.filename).toList();
          
          final updatedNote = localNote.copyWith(
            text: serverNote.text,
            updatedAt: serverNote.updatedAt,
            isPinned: serverNote.isPinned,
            tags: serverNote.tags,
            imagePaths: imagePaths,
            audioPaths: audioPaths,
            serverId: serverNote.id,
            lastSyncedAt: DateTime.now(),
            isDirty: false,
          );
          await repository.updateNoteForSync(updatedNote);
        }
      }
    }
  }

  /// Conflict resolution: return true if server version should be used
  bool _shouldUseServerVersion(Note local, SyncNotePayload server) {
    if (SyncConfig.serverWinsConflicts) {
      return true;
    }

    // Last-write-wins based on updatedAt timestamp
    return server.updatedAt.isAfter(local.updatedAt);
  }

  /// Queue a note for sync
  Future<void> queueNoteForSync(Note note, String operation) async {
    print('SyncEngine: queueNoteForSync called for ${note.id}, op: $operation');
    // Use new SyncQueue API with media paths
    if (operation == 'create') {
      await syncQueue.enqueueCreate(note, note.imagePaths, note.audioPaths);
    } else if (operation == 'update') {
      await syncQueue.enqueueUpdate(note, note.imagePaths, note.audioPaths);
    } else if (operation == 'delete') {
      await syncQueue.enqueueDelete(note);
    }
    print('SyncEngine: Enqueued successfully');

    // Trigger immediate sync if online and signed in
    if (authManager.isSignedIn) {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity != ConnectivityResult.none) {
        print('SyncEngine: Online and signed in, triggering sync...');
        sync(); // Non-blocking
      } else {
        print('SyncEngine: Offline, sync deferred');
      }
    } else {
      print('SyncEngine: Not signed in, sync deferred');
    }
  }

  /// Perform full resync (clear local data and pull from server)
  Future<void> fullResync() async {
    if (!authManager.isSignedIn) {
      throw Exception('Must be signed in to perform full resync');
    }

    try {
      _status = SyncStatus.syncing;
      _errorMessage = null;
      notifyListeners();

      // Clear sync queue  
      // Note: SyncQueue doesn't have clear() anymore, pending items will be removed

      // Pull all notes from server
      final response = await syncClient.fetchLatestNotes(limit: 1000);

      // Save media files first
      for (final serverMedia in response.media) {
        try {
          final bytes = MediaUtils.decodeBase64ToBytes(serverMedia.dataBase64);
          
          if (serverMedia.kind == 'image') {
            final imageStore = repository.imageStore;
            await imageStore.saveBytes(serverMedia.filename, bytes);
          } else if (serverMedia.kind == 'audio') {
            final audioStore = repository.audioStore;
            await audioStore.saveBytes(serverMedia.filename, bytes);
          }
        } catch (e) {
          print('Error saving media ${serverMedia.id}: $e');
        }
      }

      // Clear local notes and recreate from server
      final allLocalNotes = await repository.getAllNotes();
      for (final note in allLocalNotes) {
        await repository.deleteNoteById(note.id);
      }

      // Create notes from server
      for (final serverNote in response.notes) {
        // Get media for this note
        final notesMedia = response.media.where((m) => m.noteId == serverNote.id).toList();
        final imagePaths = notesMedia.where((m) => m.kind == 'image').map((m) => m.filename).toList();
        final audioPaths = notesMedia.where((m) => m.kind == 'audio').map((m) => m.filename).toList();
        
        final note = Note(
          id: serverNote.id,
          text: serverNote.text,
          createdAt: serverNote.createdAt,
          updatedAt: serverNote.updatedAt,
          isPinned: serverNote.isPinned,
          tags: serverNote.tags,
          imagePaths: imagePaths,
          audioPaths: audioPaths,
          serverId: serverNote.id,
          lastSyncedAt: DateTime.now(),
          isDirty: false,
        );
        await repository.insertNoteForSync(note);
      }

      _status = SyncStatus.success;
      _lastSyncTime = DateTime.now();
    } catch (e) {
      _status = SyncStatus.error;
      _errorMessage = e.toString();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _periodicSyncTimer?.cancel();
    super.dispose();
  }
}
