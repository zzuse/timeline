import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline/services/sync_engine.dart';
import 'package:timeline/services/sync_queue.dart';
import 'package:timeline/models/note.dart';
import 'package:timeline/services/notesync_client.dart';
import 'package:timeline/services/auth_session_manager.dart';
import 'package:timeline/data/image_store.dart';
import 'package:timeline/data/audio_store.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:path/path.dart' as path;

import '../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SyncEngine syncEngine;
  late MockNotesRepository mockRepository;
  late MockAuthSessionManager mockAuthManager;
  late MockNotesyncClient mockSyncClient;
  late MockSyncQueue mockSyncQueue;
  
  // Mock channels for I/O if needed (though we rely on Mock Stores)
  const MethodChannel channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('media_sync_test_');
    
    // Mock connectivity to be always online
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return 'wifi';
    });
  });

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
    channel.setMockMethodCallHandler(null);
  });

  setUp(() async {
    mockRepository = MockNotesRepository();
    mockAuthManager = MockAuthSessionManager();
    mockSyncClient = MockNotesyncClient();
    mockSyncQueue = MockSyncQueue(); // Our enhanced mock
    
    mockAuthManager.setAccessToken('valid-token');

    syncEngine = SyncEngine(
      repository: mockRepository,
      authManager: mockAuthManager,
      syncClient: mockSyncClient,
      syncQueue: mockSyncQueue,
    );
  });
  
  tearDown(() {
    syncEngine.dispose();
  });

  test('SyncEngine sends correct media payload for image upload', () async {
    // 1. Prepare dummy image file on disk
    final imageBytes = [0xFF, 0xD8, 0xFF, 0xE0, 0x01, 0x02]; // Fake JPEG data
    final imageBase64 = base64Encode(imageBytes);
    final imageHash = sha256.convert(imageBytes).toString();
    
    final imageFile = File(path.join(tempDir.path, 'test_image.jpg'));
    await imageFile.writeAsBytes(imageBytes);
    
    // 2. Prepare Queued Media
    final mediaId = 'img-1';
    final noteId = 'note-1';
    final filename = 'test_image.jpg';
    
    final queuedMedia = SyncQueuedMedia(
      id: mediaId,
      noteId: noteId,
      kind: 'image',
      filename: filename,
      localPath: imageFile.path, // Use correct field name (was originalPath)
      checksum: imageHash,
      contentType: 'image/jpeg',
    );
    
    // 3. Register file with MockSyncQueue so SyncEngine can find it via getMediaFile
    // SyncQueue implementation reads from its internal storage, here valid mocks bypass that
    // but SyncEngine calls syncQueue.getMediaFile(media).
    mockSyncQueue.registerMediaFile(filename, imageFile);
    
    // 4. Inject Item into Queue
    final note = Note(
      id: noteId, 
      text: 'Image Note', 
      createdAt: DateTime.now(), 
      updatedAt: DateTime.now()
    );
    
    final queueItem = SyncQueueItem(
      opId: 'op-123',
      opType: 'create',
      note: SyncQueuedNote(
        id: note.id,
        text: note.text,
        isPinned: note.isPinned,
        tags: note.tags,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
      ),
      media: [queuedMedia],
    );
    
    mockSyncQueue.addItem(queueItem);
    
    // 5. Setup successful sync response
    mockSyncClient.setSyncResponse(SyncResponse(results: [
      SyncNoteResult(
        noteId: noteId,
        result: 'success',
        note: SyncNotePayload.fromNote(note),
      )
    ]));
    
    // 6. trigger sync
    await syncEngine.sync();
    
    // 7. Verify Payload
    expect(mockSyncClient.lastSyncRequest, isNotNull);
    final request = mockSyncClient.lastSyncRequest!;
    expect(request.ops.length, 1);
    
    final op = request.ops.first;
    expect(op.media.length, 1);
    
    final mediaPayload = op.media.first;
    expect(mediaPayload.id, equals(mediaId));
    expect(mediaPayload.kind, equals('image'));
    expect(mediaPayload.filename, equals(filename));
    expect(mediaPayload.contentType, equals('image/jpeg'));
    expect(mediaPayload.checksum, equals(imageHash));
    expect(mediaPayload.dataBase64, equals(imageBase64)); // Verification of encoding logic
  });

  test('SyncEngine downloads and saves media files', () async {
    // 1. Prepare server response with media
    final imageBytes = [0xAA, 0xBB, 0xCC]; 
    final imageBase64 = base64Encode(imageBytes);
    final filename = 'server_image.jpg';
    
    final serverMedia = SyncMediaPayload(
      id: 'server-media-1',
      noteId: 'server-note-1',
      kind: 'image',
      filename: filename,
      contentType: 'image/jpeg',
      checksum: 'fake-hash',
      dataBase64: imageBase64
    );
    
    final serverNote = SyncNotePayload(
      id: 'server-note-1',
      text: 'Note with Image',
      isPinned: false,
      tags: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    mockSyncClient.setFetchResponse(NotesyncRestoreResponse(
      notes: [serverNote],
      media: [serverMedia],
    ));
    
    // 2. Mock full resync (which calls fetchLatestNotes)
    // We use fullResync or normal sync's pull logic? 
    // sync() calls _pullServerNotes logic too if we set it up.
    // Let's use fullResync for clarity as it always fetches.
    await syncEngine.fullResync();
    
    // 3. Verify ImageStore received the data
    final mockImageStore = mockRepository.imageStore as MockImageStore;
    
    expect(mockImageStore.hasImage(filename), isTrue);
    expect(mockImageStore.getImageBytes(filename), equals(imageBytes)); // Verification of decoding logic
    
    // 4. Verify Note inserted
    expect(mockRepository.lastCreatedNote, isNotNull);
    expect(mockRepository.lastCreatedNote!.id, 'server-note-1');
  });
}
