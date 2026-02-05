import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline/services/sync_engine.dart';
import 'package:timeline/models/note.dart';
import 'package:timeline/services/notesync_client.dart';
import 'package:timeline/services/auth_session_manager.dart'; // Add this import

// Mocks
import '../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SyncEngine syncEngine;
  late MockNotesRepository mockRepository;
  late MockAuthSessionManager mockAuthManager;
  late MockNotesyncClient mockSyncClient;
  late MockSyncQueue mockSyncQueue;

  // Mock connectivity
  const MethodChannel channel = MethodChannel('dev.fluttercommunity.plus/connectivity');

  setUp(() async {
    // Default to wifi
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return 'wifi';
    });

    mockRepository = MockNotesRepository();
    mockAuthManager = MockAuthSessionManager();
    mockSyncClient = MockNotesyncClient();
    mockSyncQueue = MockSyncQueue();
    
    // Auth manager needs to be signed in for sync to run
    mockAuthManager.setAccessToken('fake-token');

    syncEngine = SyncEngine(
      repository: mockRepository,
      authManager: mockAuthManager,
      syncClient: mockSyncClient,
      syncQueue: mockSyncQueue,
    );
  });

  tearDown(() {
    syncEngine.dispose();
    channel.setMockMethodCallHandler(null);
  });

  group('SyncEngine', () {
    test('queueNoteForSync enqueues create operation', () async {
      final note = Note.create(text: 'Test Note');
      
      await syncEngine.queueNoteForSync(note, 'create');
      
      final pending = await mockSyncQueue.pending();
      expect(pending.length, 1);
      expect(pending.first.opType, 'create');
      expect(pending.first.note.id, note.id);
      
      // Allow async sync() trigger to complete before tearDown disposes the engine
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('sync pushes dirty notes', () async {
      // 1. Setup dirty note in repo
      final dirtyNote = Note.create(text: 'Dirty Note');
      // Create it directly (mock repo implementation differs, assuming simple add)
      // Note.create defaults to isDirty=true
      await mockRepository.insertNoteForSync(dirtyNote); 

      // 2. Setup sync client response
      mockSyncClient.setSyncResponse(SyncResponse(results: [
        SyncNoteResult(
          noteId: dirtyNote.id,
          result: 'success',
          note: SyncNotePayload.fromNote(dirtyNote),
        )
      ]));
      mockSyncClient.setFetchResponse(NotesyncRestoreResponse(notes: [], media: []));

      // 3. Run sync
      await syncEngine.sync();

      // 4. Verify status
      expect(syncEngine.status, SyncStatus.success);
      expect(syncEngine.lastSyncTime, isNotNull);
      
      // Verify repo update called
      expect(mockRepository.lastUpdatedNote, isNotNull);
      expect(mockRepository.lastUpdatedNote!.id, dirtyNote.id);
      expect(mockRepository.lastUpdatedNote!.isDirty, false); // Should be cleared
      
      // Verify data sent to server
      expect(mockSyncClient.lastSyncRequest, isNotNull);
      expect(mockSyncClient.lastSyncRequest!.ops.length, 1);
      expect(mockSyncClient.lastSyncRequest!.ops.first.note.id, dirtyNote.id);
    });
    
    test('sync pulls changes from server', () async {
      // 1. Setup server response with new note
      mockSyncClient.setSyncResponse(SyncResponse(results: []));
      
      final serverNote = SyncNotePayload(
        id: 'server-1',
        text: 'Server Note',
        isPinned: false,
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      mockSyncClient.setFetchResponse(NotesyncRestoreResponse(
        notes: [serverNote],
        media: [],
      ));

      // 2. Run sync
      await syncEngine.sync();

      // 3. Verify note inserted 
      expect(mockRepository.lastCreatedNote, isNotNull);
      expect(mockRepository.lastCreatedNote!.id, 'server-1');
      expect(mockRepository.lastCreatedNote!.text, 'Server Note');
    });

    test('sync handles conflicts (server wins)', () async {
      // 1. Setup local note - construct manually to control isDirty
      final localNote = Note(
        id: 'local-1',
        text: 'Local Version',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isDirty: false,
      );
      await mockRepository.insertNoteForSync(localNote);

      // 2. Setup server response with updated version
      mockSyncClient.setSyncResponse(SyncResponse(results: []));
      
      final serverNote = SyncNotePayload(
        id: localNote.id,
        text: 'Server Version',
        isPinned: false,
        tags: [],
        createdAt: localNote.createdAt,
        updatedAt: localNote.updatedAt.add(const Duration(minutes: 1)), // Server is newer
      );
       mockSyncClient.setFetchResponse(NotesyncRestoreResponse(
        notes: [serverNote],
        media: [],
      ));

      // 3. Run sync
      await syncEngine.sync();

      // 4. Verify local note updated
      expect(mockRepository.lastUpdatedNote, isNotNull);
      expect(mockRepository.lastUpdatedNote!.text, 'Server Version');
    });

    test('fullResync clears local data and fetches all', () async {
      // 1. Setup local data
      mockRepository.addNote(Note.create(text: 'Old Note'));
      
      // 2. Setup fetch response
      final freshNote = SyncNotePayload(
        id: 'fresh-1',
        text: 'Fresh Note',
        isPinned: false,
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Mock fetchLatestNotes for full resync
      mockSyncClient.setFetchResponse(NotesyncRestoreResponse(
        notes: [freshNote],
        media: [],
      ));

      // 3. Run full resync
      await syncEngine.fullResync();

      // 4. Verify old notes deleted (mock repo verify)
      expect(mockRepository.lastDeletedNoteId, isNotNull);
      
      // 5. Verify new note added
      expect(mockRepository.lastCreatedNote, isNotNull);
      expect(mockRepository.lastCreatedNote!.text, 'Fresh Note');
    });
    
    test('sync queues items when offline', () async {
      // Verify connectivity check
      // We can't easily change the mock channel mid-test without re-setting it and awaiting event loop
      // But we can check behavior if connectivity throws or returns none.
      
      channel.setMockMethodCallHandler((MethodCall methodCall) async {
        return 'none';
      });
      
      final note = Note.create(text: 'Offline Note');
      await syncEngine.queueNoteForSync(note, 'create');
      
      // Should be in queue
      final pending = await mockSyncQueue.pending();
      expect(pending.length, 1);
      
      // Sync should NOT have run (status still idle or error depending on how it was triggered)
      // `queueNoteForSync` triggers sync() but it checks connectivity inside sync() too.
      // If sync() ran, it would catch 'No network' and set error.
      // But `queueNoteForSync` checks connectivity BEFORE calling sync().
      // See code: `if (connectivity != ConnectivityResult.none)`
      
      // So status should be idle because sync() was never called.
      expect(syncEngine.status, SyncStatus.idle);
    });
  });
}
