import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../data/image_store.dart';
import '../data/audio_store.dart';
import 'media_utils.dart';
import 'notesync_client.dart';

/// Queued note snapshot
class SyncQueuedNote {
  final String id;
  final String text;
  final bool isPinned;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  SyncQueuedNote({
    required this.id,
    required this.text,
    required this.isPinned,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isPinned': isPinned,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
      };

  factory SyncQueuedNote.fromJson(Map<String, dynamic> json) => SyncQueuedNote(
        id: json['id'],
        text: json['text'],
        isPinned: json['isPinned'],
        tags: List<String>.from(json['tags']),
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
        deletedAt: json['deletedAt'] != null ? DateTime.parse(json['deletedAt']) : null,
      );
}

/// Queued media metadata
class SyncQueuedMedia {
  final String id;
  final String noteId;
  final String kind; // "image" or "audio"
  final String filename;
  final String contentType;
  final String checksum;
  final String localPath; // Relative path in queue media directory

  SyncQueuedMedia({
    required this.id,
    required this.noteId,
    required this.kind,
    required this.filename,
    required this.contentType,
    required this.checksum,
    required this.localPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'noteId': noteId,
        'kind': kind,
        'filename': filename,
        'contentType': contentType,
        'checksum': checksum,
        'localPath': localPath,
      };

  factory SyncQueuedMedia.fromJson(Map<String, dynamic> json) => SyncQueuedMedia(
        id: json['id'],
        noteId: json['noteId'],
        kind: json['kind'],
        filename: json['filename'],
        contentType: json['contentType'],
        checksum: json['checksum'],
        localPath: json['localPath'],
      );
}

/// Complete queue item
class SyncQueueItem {
  final String opId;
  final String opType; // "create", "update", "delete"
  final SyncQueuedNote note;
  final List<SyncQueuedMedia> media;

  SyncQueueItem({
    required this.opId,
    required this.opType,
    required this.note,
    this.media = const [],
  });

  Map<String, dynamic> toJson() => {
        'opId': opId,
        'opType': opType,
        'note': note.toJson(),
        'media': media.map((m) => m.toJson()).toList(),
      };

 factory SyncQueueItem.fromJson(Map<String, dynamic> json) => SyncQueueItem(
        opId: json['opId'],
        opType: json['opType'],
        note: SyncQueuedNote.fromJson(json['note']),
        media: (json['media'] as List<dynamic>)
            .map((m) => SyncQueuedMedia.fromJson(m))
            .toList(),
      );
}

/// Persistent queue for sync operations (matches iOS SyncQueue)
class SyncQueue {
  late Directory _baseDir;
  late Directory _mediaDir;
  final _uuid = const Uuid();
  final _imageStore = ImageStore();
  final _audioStore = AudioStore();

  /// Initialize queue directories
  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    _baseDir = Directory(path.join(appDir.path, 'SyncQueue'));
    _mediaDir = Directory(path.join(_baseDir.path, 'Media'));

    await _baseDir.create(recursive: true);
    await _mediaDir.create(recursive: true);
  }

  /// Enqueue create operation
  Future<void> enqueueCreate(Note note, List<String> imagePaths, List<String> audioPaths) async {
    await _enqueue(
      note: note,
      imagePaths: imagePaths,
      audioPaths: audioPaths,
      opType: 'create',
      deletedAt: null,
    );
  }

  /// Enqueue update operation
  Future<void> enqueueUpdate(Note note, List<String> imagePaths, List<String> audioPaths) async {
    await _enqueue(
      note: note,
      imagePaths: imagePaths,
      audioPaths: audioPaths,
      opType: 'update',
      deletedAt: null,
    );
  }

  /// Enqueue delete operation
  Future<void> enqueueDelete(Note note) async {
    await _enqueue(
      note: note,
      imagePaths: note.imagePaths,
      audioPaths: note.audioPaths,
      opType: 'delete',
      deletedAt: DateTime.now(),
    );
  }

  /// Get all pending queue items
  Future<List<SyncQueueItem>> pending() async {
    final files = _baseDir
        .listSync()
        .where((f) => f is File && f.path.endsWith('.json'))
        .cast<File>()
        .toList();

    files.sort((a, b) => a.path.compareTo(b.path));

    return await Future.wait(
      files.map((file) async {
        final json = jsonDecode(await file.readAsString());
        return SyncQueueItem.fromJson(json);
      }),
    );
  }

  /// Get count of pending items
  Future<int> pendingCount() async {
    final items = await pending();
    return items.length;
  }

  /// Remove completed items from queue
  Future<void> remove(List<SyncQueueItem> items) async {
    final files = _baseDir
        .listSync()
        .where((f) => f is File && f.path.endsWith('.json'))
        .cast<File>()
        .toList();

    for (final item in items) {
      final matchingFiles = files.where((f) => f.path.contains(item.opId));
      for (final file in matchingFiles) {
        await file.delete();
      }

      // Clean up media files
      for (final media in item.media) {
        final mediaFile = File(path.join(_mediaDir.path, media.localPath));
        if (await mediaFile.exists()) {
          await mediaFile.delete();
        }
      }
    }
  }

  /// Get media file for a queued media item
  File getMediaFile(SyncQueuedMedia media) {
    return File(path.join(_mediaDir.path, media.localPath));
  }

  // Private helper to enqueue operations
  Future<void> _enqueue({
    required Note note,
    required List<String> imagePaths,
    required List<String> audioPaths,
    required String opType,
    required DateTime? deletedAt,
  }) async {
    final opId = _uuid.v4();

    final queuedNote = SyncQueuedNote(
      id: note.id,
      text: note.text,
      isPinned: note.isPinned,
      tags: note.tags,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
      deletedAt: deletedAt,
    );

    final media = await _copyMedia(note.id, imagePaths, audioPaths);

    final item = SyncQueueItem(
      opId: opId,
      opType: opType,
      note: queuedNote,
      media: media,
    );

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = 'op_${timestamp}_$opId.json';
    final file = File(path.join(_baseDir.path, filename));

    await file.writeAsString(jsonEncode(item.toJson()));
  }

  // Copy media files to queue directory
  Future<List<SyncQueuedMedia>> _copyMedia(
    String noteId,
    List<String> imagePaths,
    List<String> audioPaths,
  ) async {
    final List<SyncQueuedMedia> queued = [];

    // Copy images
    for (final imagePath in imagePaths) {
      try {
        final sourceFile = await _imageStore.getFile(imagePath);
        final id = _uuid.v4();
        final filename = '$id.jpg';
        final destFile = File(path.join(_mediaDir.path, filename));

        await sourceFile.copy(destFile.path);

        final checksum = await MediaUtils.calculateChecksum(destFile);
        final contentType = MediaUtils.getContentType('image', filename);

        queued.add(SyncQueuedMedia(
          id: id,
          noteId: noteId,
          kind: 'image',
          filename: filename,
          contentType: contentType,
          checksum: checksum,
          localPath: filename,
        ));
      } catch (e) {
        print('Error copying image $imagePath: $e');
      }
    }

    // Copy audio
    for (final audioPath in audioPaths) {
      try {
        final sourceFile = await _audioStore.getFile(audioPath);
        final id = _uuid.v4();
        final filename = '$id.m4a';
        final destFile = File(path.join(_mediaDir.path, filename));

        await sourceFile.copy(destFile.path);

        final checksum = await MediaUtils.calculateChecksum(destFile);
        final contentType = MediaUtils.getContentType('audio', filename);

        queued.add(SyncQueuedMedia(
          id: id,
          noteId: noteId,
          kind: 'audio',
          filename: filename,
          contentType: contentType,
          checksum: checksum,
          localPath: filename,
        ));
      } catch (e) {
        print('Error copying audio $audioPath: $e');
      }
    }

    return queued;
  }
}
