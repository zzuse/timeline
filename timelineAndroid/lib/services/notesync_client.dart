import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/sync_config.dart';
import '../services/auth_session_manager.dart';
import '../models/note.dart';

/// Sync operation types
enum SyncOpType {
  create,
  update,
  delete,
}

/// Payload for a single note in sync request
class SyncNotePayload {
  final String id;
  final String text;
  final bool isPinned;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  SyncNotePayload({
    required this.id,
    required this.text,
    required this.isPinned,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isPinned': isPinned,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
    };
  }

  factory SyncNotePayload.fromJson(Map<String, dynamic> json) {
    return SyncNotePayload(
      id: json['id'],
      text: json['text'],
      isPinned: json['isPinned'],
      tags: List<String>.from(json['tags']),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      deletedAt: json['deletedAt'] != null ? DateTime.parse(json['deletedAt']) : null,
    );
  }

  factory SyncNotePayload.fromNote(Note note, {DateTime? deletedAt}) {
    return SyncNotePayload(
      id: note.id,
      text: note.text,
      isPinned: note.isPinned,
      tags: note.tags,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
      deletedAt: deletedAt,
    );
  }
}

/// Media payload for sync (images/audio)
class SyncMediaPayload {
  final String id;
  final String noteId;
  final String kind; // "image" or "audio"
  final String filename;
  final String contentType; // "image/jpeg" or "audio/m4a"
  final String checksum; // SHA256 hash
  final String dataBase64; // Base64-encoded file data

  SyncMediaPayload({
    required this.id,
    required this.noteId,
    required this.kind,
    required this.filename,
    required this.contentType,
    required this.checksum,
    required this.dataBase64,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'noteId': noteId,
      'kind': kind,
      'filename': filename,
      'contentType': contentType,
      'checksum': checksum,
      'dataBase64': dataBase64,
    };
  }

  factory SyncMediaPayload.fromJson(Map<String, dynamic> json) {
    return SyncMediaPayload(
      id: json['id'],
      noteId: json['noteId'],
      kind: json['kind'],
      filename: json['filename'],
      contentType: json['contentType'],
      checksum: json['checksum'],
      dataBase64: json['dataBase64'],
    );
  }
}

/// Sync operation payload
class SyncOperationPayload {
  final String opId;
  final String opType;
  final SyncNotePayload note;
  final List<SyncMediaPayload> media;

  SyncOperationPayload({
    required this.opId,
    required this.opType,
    required this.note,
    this.media = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'opId': opId,
      'opType': opType,
      'note': note.toJson(),
      'media': media.map((m) => m.toJson()).toList(),
    };
  }
}

/// Sync request with multiple operations
class SyncRequest {
  final List<SyncOperationPayload> ops;

  SyncRequest({required this.ops});

  Map<String, dynamic> toJson() {
    return {
      'ops': ops.map((op) => op.toJson()).toList(),
    };
  }
}

/// Result for a single note in sync response
class SyncNoteResult {
  final String noteId;
  final String result;
  final SyncNotePayload note;

  SyncNoteResult({
    required this.noteId,
    required this.result,
    required this.note,
  });

  factory SyncNoteResult.fromJson(Map<String, dynamic> json) {
    return SyncNoteResult(
      noteId: json['noteId'],
      result: json['result'],
      note: SyncNotePayload.fromJson(json['note']),
    );
  }
}

/// Sync response from server
class SyncResponse {
  final List<SyncNoteResult> results;

  SyncResponse({required this.results});

  factory SyncResponse.fromJson(Map<String, dynamic> json) {
    return SyncResponse(
      results: (json['results'] as List)
          .map((r) => SyncNoteResult.fromJson(r))
          .toList(),
    );
  }
}

/// Restore response from server
class NotesyncRestoreResponse {
  final List<SyncNotePayload> notes;
  final List<SyncMediaPayload> media;

  NotesyncRestoreResponse({
    required this.notes,
    this.media = const [],
  });

  factory NotesyncRestoreResponse.fromJson(Map<String, dynamic> json) {
    return NotesyncRestoreResponse(
      notes: (json['notes'] as List)
          .map((n) => SyncNotePayload.fromJson(n))
          .toList(),
      media: (json['media'] as List? ?? [])
          .map((m) => SyncMediaPayload.fromJson(m))
          .toList(),
    );
  }
}

/// HTTP client for Notesync API
class NotesyncClient {
  final AuthSessionManager authManager;
  final http.Client httpClient;

  NotesyncClient({
    required this.authManager,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  /// Send sync request to server
  Future<SyncResponse> sendSync(SyncRequest request) async {
    final token = await authManager.getAccessToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    return await _sendSyncWithToken(request, token, didRefresh: false);
  }

  Future<SyncResponse> _sendSyncWithToken(
    SyncRequest request,
    String token, {
    required bool didRefresh,
  }) async {
    final url = Uri.parse('${SyncConfig.baseUrl}${SyncConfig.apiNotesyncEndpoint}');
    final body = json.encode(request.toJson());

    final response = await httpClient.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': SyncConfig.apiKey,
        'Authorization': 'Bearer $token',
      },
      body: body,
    );

    if (response.statusCode == 401 && !didRefresh) {
      // Token expired, try to refresh
      final refreshed = await authManager.refreshAccessToken();
      if (refreshed) {
        final newToken = await authManager.getAccessToken();
        if (newToken != null) {
          return await _sendSyncWithToken(request, newToken, didRefresh: true);
        }
      }
      throw Exception('Authentication failed');
    }

    if (response.statusCode != 200) {
      throw Exception('Sync failed: ${response.statusCode} - ${response.body}');
    }

    return SyncResponse.fromJson(json.decode(response.body));
  }

  /// Fetch latest notes from server
  Future<NotesyncRestoreResponse> fetchLatestNotes({int limit = 100}) async {
    final token = await authManager.getAccessToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    return await _fetchLatestNotesWithToken(limit, token, didRefresh: false);
  }

  Future<NotesyncRestoreResponse> _fetchLatestNotesWithToken(
    int limit,
    String token, {
    required bool didRefresh,
  }) async {
    final url = Uri.parse('${SyncConfig.baseUrl}${SyncConfig.apiNotesEndpoint}')
        .replace(queryParameters: {'limit': limit.toString()});

    final response = await httpClient.get(
      url,
      headers: {
        'X-API-Key': SyncConfig.apiKey,
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 401 && !didRefresh) {
      // Token expired, try to refresh
      final refreshed = await authManager.refreshAccessToken();
      if (refreshed) {
        final newToken = await authManager.getAccessToken();
        if (newToken != null) {
          return await _fetchLatestNotesWithToken(limit, newToken, didRefresh: true);
        }
      }
      throw Exception('Authentication failed');
    }

    if (response.statusCode != 200) {
      throw Exception('Fetch failed: ${response.statusCode} - ${response.body}');
    }

    return NotesyncRestoreResponse.fromJson(json.decode(response.body));
  }

  void dispose() {
    httpClient.close();
  }
}
