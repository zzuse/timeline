import 'package:flutter_test/flutter_test.dart';
import 'package:timeline/models/note.dart';

void main() {
  group('Note', () {
    group('Note.create()', () {
      test('creates note with auto-generated ID', () {
        final note = Note.create(text: 'Test note');
        
        expect(note.id, isNotEmpty);
        expect(note.text, 'Test note');
      });

      test('creates note with current timestamp', () {
        final before = DateTime.now();
        final note = Note.create(text: 'Test note');
        final after = DateTime.now();
        
        expect(note.createdAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
        expect(note.createdAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
        expect(note.createdAt, equals(note.updatedAt));
      });

      test('creates note with default values', () {
        final note = Note.create(text: 'Test note');
        
        expect(note.isPinned, isFalse);
        expect(note.imagePaths, isEmpty);
        expect(note.audioPaths, isEmpty);
        expect(note.tags, isEmpty);
        expect(note.isDirty, isTrue);
        expect(note.serverId, isNull);
        expect(note.lastSyncedAt, isNull);
      });

      test('creates note with provided media paths', () {
        final note = Note.create(
          text: 'Test note',
          imagePaths: ['image1.jpg', 'image2.jpg'],
          audioPaths: ['audio1.m4a'],
          tags: ['tag1', 'tag2'],
        );
        
        expect(note.imagePaths, ['image1.jpg', 'image2.jpg']);
        expect(note.audioPaths, ['audio1.m4a']);
        expect(note.tags, ['tag1', 'tag2']);
      });
    });

    group('Note.copyWith()', () {
      late Note originalNote;

      setUp(() {
        originalNote = Note(
          id: 'test-id',
          text: 'Original text',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
          isPinned: false,
          imagePaths: ['image1.jpg'],
          audioPaths: ['audio1.m4a'],
          tags: ['tag1'],
          serverId: 'server-123',
          lastSyncedAt: DateTime(2024, 1, 1),
          isDirty: false,
        );
      });

      test('creates copy with updated text', () {
        final updated = originalNote.copyWith(text: 'New text');
        
        expect(updated.text, 'New text');
        expect(updated.id, originalNote.id);
        expect(updated.createdAt, originalNote.createdAt);
      });

      test('creates copy with updated isPinned', () {
        final updated = originalNote.copyWith(isPinned: true);
        
        expect(updated.isPinned, isTrue);
        expect(updated.text, originalNote.text);
      });

      test('creates copy with updated imagePaths', () {
        final updated = originalNote.copyWith(imagePaths: ['new1.jpg', 'new2.jpg']);
        
        expect(updated.imagePaths, ['new1.jpg', 'new2.jpg']);
      });

      test('creates copy with updated sync fields', () {
        final syncTime = DateTime.now();
        final updated = originalNote.copyWith(
          serverId: 'new-server-id',
          lastSyncedAt: syncTime,
          isDirty: true,
        );
        
        expect(updated.serverId, 'new-server-id');
        expect(updated.lastSyncedAt, syncTime);
        expect(updated.isDirty, isTrue);
      });

      test('preserves original values when not specified', () {
        final updated = originalNote.copyWith(text: 'New text');
        
        expect(updated.isPinned, originalNote.isPinned);
        expect(updated.serverId, originalNote.serverId);
        expect(updated.tags, originalNote.tags);
      });
    });

    group('Note.toMap()', () {
      test('serializes all fields correctly', () {
        final note = Note(
          id: 'test-id',
          text: 'Test text',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1704067200000),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1704067200000),
          isPinned: true,
          imagePaths: ['img1.jpg', 'img2.jpg'],
          audioPaths: ['audio1.m4a'],
          tags: ['tag1', 'tag2'],
          serverId: 'server-123',
          lastSyncedAt: DateTime.fromMillisecondsSinceEpoch(1704067200000),
          isDirty: false,
        );

        final map = note.toMap();

        expect(map['id'], 'test-id');
        expect(map['text'], 'Test text');
        expect(map['createdAt'], 1704067200000);
        expect(map['updatedAt'], 1704067200000);
        expect(map['isPinned'], 1);
        expect(map['imagePaths'], 'img1.jpg|img2.jpg');
        expect(map['audioPaths'], 'audio1.m4a');
        expect(map['tags'], 'tag1|tag2');
        expect(map['serverId'], 'server-123');
        expect(map['lastSyncedAt'], 1704067200000);
        expect(map['isDirty'], 0);
      });

      test('serializes empty lists as empty strings', () {
        final note = Note.create(text: 'Test');
        final map = note.toMap();

        expect(map['imagePaths'], '');
        expect(map['audioPaths'], '');
        expect(map['tags'], '');
      });

      test('serializes null sync fields correctly', () {
        final note = Note.create(text: 'Test');
        final map = note.toMap();

        expect(map['serverId'], isNull);
        expect(map['lastSyncedAt'], isNull);
      });
    });

    group('Note.fromMap()', () {
      test('deserializes all fields correctly', () {
        final map = {
          'id': 'test-id',
          'text': 'Test text',
          'createdAt': 1704067200000,
          'updatedAt': 1704067200000,
          'isPinned': 1,
          'imagePaths': 'img1.jpg|img2.jpg',
          'audioPaths': 'audio1.m4a',
          'tags': 'tag1|tag2',
          'serverId': 'server-123',
          'lastSyncedAt': 1704067200000,
          'isDirty': 0,
        };

        final note = Note.fromMap(map);

        expect(note.id, 'test-id');
        expect(note.text, 'Test text');
        expect(note.createdAt.millisecondsSinceEpoch, 1704067200000);
        expect(note.updatedAt.millisecondsSinceEpoch, 1704067200000);
        expect(note.isPinned, isTrue);
        expect(note.imagePaths, ['img1.jpg', 'img2.jpg']);
        expect(note.audioPaths, ['audio1.m4a']);
        expect(note.tags, ['tag1', 'tag2']);
        expect(note.serverId, 'server-123');
        expect(note.lastSyncedAt?.millisecondsSinceEpoch, 1704067200000);
        expect(note.isDirty, isFalse);
      });

      test('handles null and empty paths', () {
        final map = {
          'id': 'test-id',
          'text': 'Test text',
          'createdAt': 1704067200000,
          'updatedAt': 1704067200000,
          'isPinned': 0,
          'imagePaths': null,
          'audioPaths': '',
          'tags': null,
          'serverId': null,
          'lastSyncedAt': null,
          'isDirty': 1,
        };

        final note = Note.fromMap(map);

        expect(note.imagePaths, isEmpty);
        expect(note.audioPaths, isEmpty);
        expect(note.tags, isEmpty);
        expect(note.serverId, isNull);
        expect(note.lastSyncedAt, isNull);
      });

      test('handles missing isDirty (defaults to true)', () {
        final map = {
          'id': 'test-id',
          'text': 'Test text',
          'createdAt': 1704067200000,
          'updatedAt': 1704067200000,
          'isPinned': 0,
          'imagePaths': null,
          'audioPaths': null,
          'tags': null,
          'serverId': null,
          'lastSyncedAt': null,
          'isDirty': null,
        };

        final note = Note.fromMap(map);
        expect(note.isDirty, isTrue);
      });
    });

    group('Round-trip serialization', () {
      test('toMap -> fromMap preserves all data', () {
        final original = Note(
          id: 'test-id',
          text: 'Test text with special chars: "quotes" & ampersand',
          createdAt: DateTime(2024, 1, 15, 10, 30, 45),
          updatedAt: DateTime(2024, 1, 16, 14, 20, 30),
          isPinned: true,
          imagePaths: ['path/to/image1.jpg', 'path/to/image2.png'],
          audioPaths: ['audio/file.m4a'],
          tags: ['work', 'important', 'project-alpha'],
          serverId: 'srv-abc-123',
          lastSyncedAt: DateTime(2024, 1, 16, 14, 20, 30),
          isDirty: false,
        );

        final map = original.toMap();
        final restored = Note.fromMap(map);

        expect(restored.id, original.id);
        expect(restored.text, original.text);
        expect(restored.createdAt, original.createdAt);
        expect(restored.updatedAt, original.updatedAt);
        expect(restored.isPinned, original.isPinned);
        expect(restored.imagePaths, original.imagePaths);
        expect(restored.audioPaths, original.audioPaths);
        expect(restored.tags, original.tags);
        expect(restored.serverId, original.serverId);
        expect(restored.lastSyncedAt, original.lastSyncedAt);
        expect(restored.isDirty, original.isDirty);
      });
    });
  });
}
