import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline/services/sync_queue.dart';
import 'package:timeline/models/note.dart';

void main() {
  group('SyncQueuedNote', () {
    test('toJson() serializes all fields', () {
      final queuedNote = SyncQueuedNote(
        id: 'note-123',
        text: 'Test note',
        isPinned: true,
        tags: ['tag1', 'tag2'],
        createdAt: DateTime.parse('2024-01-15T10:30:00Z'),
        updatedAt: DateTime.parse('2024-01-16T14:20:00Z'),
      );

      final json = queuedNote.toJson();

      expect(json['id'], 'note-123');
      expect(json['text'], 'Test note');
      expect(json['isPinned'], true);
      expect(json['tags'], ['tag1', 'tag2']);
      expect(json['createdAt'], '2024-01-15T10:30:00.000Z');
      expect(json['updatedAt'], '2024-01-16T14:20:00.000Z');
    });

    test('toJson() includes deletedAt when set', () {
      final queuedNote = SyncQueuedNote(
        id: 'note-123',
        text: 'Deleted note',
        isPinned: false,
        tags: [],
        createdAt: DateTime.parse('2024-01-15T10:30:00Z'),
        updatedAt: DateTime.parse('2024-01-16T14:20:00Z'),
        deletedAt: DateTime.parse('2024-01-17T09:00:00Z'),
      );

      final json = queuedNote.toJson();

      expect(json['deletedAt'], '2024-01-17T09:00:00.000Z');
    });

    test('fromJson() parses all fields', () {
      final json = {
        'id': 'note-123',
        'text': 'Test note',
        'isPinned': true,
        'tags': ['tag1', 'tag2'],
        'createdAt': '2024-01-15T10:30:00.000Z',
        'updatedAt': '2024-01-16T14:20:00.000Z',
      };

      final queuedNote = SyncQueuedNote.fromJson(json);

      expect(queuedNote.id, 'note-123');
      expect(queuedNote.text, 'Test note');
      expect(queuedNote.isPinned, true);
      expect(queuedNote.tags, ['tag1', 'tag2']);
    });

    test('round-trip serialization works', () {
      final original = SyncQueuedNote(
        id: 'note-456',
        text: 'Round trip test',
        isPinned: false,
        tags: ['work'],
        createdAt: DateTime(2024, 1, 15, 10, 30),
        updatedAt: DateTime(2024, 1, 16, 14, 20),
      );

      final json = original.toJson();
      final restored = SyncQueuedNote.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.text, original.text);
      expect(restored.isPinned, original.isPinned);
      expect(restored.tags, original.tags);
    });
  });

  group('SyncQueuedMedia', () {
    test('toJson() serializes all fields', () {
      final media = SyncQueuedMedia(
        id: 'media-123',
        noteId: 'note-456',
        kind: 'image',
        filename: 'photo.jpg',
        contentType: 'image/jpeg',
        checksum: 'abc123def456',
        localPath: 'queue/media/photo.jpg',
      );

      final json = media.toJson();

      expect(json['id'], 'media-123');
      expect(json['noteId'], 'note-456');
      expect(json['kind'], 'image');
      expect(json['filename'], 'photo.jpg');
      expect(json['contentType'], 'image/jpeg');
      expect(json['checksum'], 'abc123def456');
      expect(json['localPath'], 'queue/media/photo.jpg');
    });

    test('fromJson() parses all fields', () {
      final json = {
        'id': 'media-789',
        'noteId': 'note-111',
        'kind': 'audio',
        'filename': 'recording.m4a',
        'contentType': 'audio/m4a',
        'checksum': 'xyz789',
        'localPath': 'queue/media/recording.m4a',
      };

      final media = SyncQueuedMedia.fromJson(json);

      expect(media.id, 'media-789');
      expect(media.noteId, 'note-111');
      expect(media.kind, 'audio');
      expect(media.filename, 'recording.m4a');
      expect(media.localPath, 'queue/media/recording.m4a');
    });
  });

  group('SyncQueueItem', () {
    test('toJson() serializes complete item', () {
      final item = SyncQueueItem(
        opId: 'op-123',
        opType: 'create',
        note: SyncQueuedNote(
          id: 'note-123',
          text: 'Test',
          isPinned: false,
          tags: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        media: [
          SyncQueuedMedia(
            id: 'media-1',
            noteId: 'note-123',
            kind: 'image',
            filename: 'img.jpg',
            contentType: 'image/jpeg',
            checksum: 'abc',
            localPath: 'queue/media/img.jpg',
          ),
        ],
      );

      final json = item.toJson();

      expect(json['opId'], 'op-123');
      expect(json['opType'], 'create');
      expect(json['note'], isA<Map>());
      expect(json['media'], isA<List>());
      expect((json['media'] as List).length, 1);
    });

    test('fromJson() parses complete item', () {
      final json = {
        'opId': 'op-456',
        'opType': 'update',
        'note': {
          'id': 'note-456',
          'text': 'Updated text',
          'isPinned': true,
          'tags': ['important'],
          'createdAt': '2024-01-15T10:30:00.000Z',
          'updatedAt': '2024-01-16T14:20:00.000Z',
        },
        'media': [],
      };

      final item = SyncQueueItem.fromJson(json);

      expect(item.opId, 'op-456');
      expect(item.opType, 'update');
      expect(item.note.text, 'Updated text');
      expect(item.note.isPinned, true);
      expect(item.media, isEmpty);
    });

    test('fromJson() parses delete item with deletedAt', () {
      final json = {
        'opId': 'op-789',
        'opType': 'delete',
        'note': {
          'id': 'note-789',
          'text': 'Deleted note',
          'isPinned': false,
          'tags': [],
          'createdAt': '2024-01-15T10:30:00.000Z',
          'updatedAt': '2024-01-16T14:20:00.000Z',
          'deletedAt': '2024-01-17T09:00:00.000Z',
        },
        'media': [],
      };

      final item = SyncQueueItem.fromJson(json);

      expect(item.opId, 'op-789');
      expect(item.opType, 'delete');
      expect(item.note.deletedAt, isNotNull);
    });

    test('fromJson() parses item with media', () {
      final json = {
        'opId': 'op-999',
        'opType': 'create',
        'note': {
          'id': 'note-999',
          'text': 'Note with media',
          'isPinned': false,
          'tags': [],
          'createdAt': '2024-01-15T10:30:00.000Z',
          'updatedAt': '2024-01-15T10:30:00.000Z',
        },
        'media': [
          {
            'id': 'media-1',
            'noteId': 'note-999',
            'kind': 'image',
            'filename': 'photo.jpg',
            'contentType': 'image/jpeg',
            'checksum': 'abc123',
            'localPath': 'queue/media/photo.jpg',
          },
          {
            'id': 'media-2',
            'noteId': 'note-999',
            'kind': 'audio',
            'filename': 'audio.m4a',
            'contentType': 'audio/m4a',
            'checksum': 'xyz789',
            'localPath': 'queue/media/audio.m4a',
          },
        ],
      };

      final item = SyncQueueItem.fromJson(json);

      expect(item.media.length, 2);
      expect(item.media[0].kind, 'image');
      expect(item.media[1].kind, 'audio');
    });
  });
}
