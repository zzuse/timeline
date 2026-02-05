import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';

import 'package:timeline/services/notesync_client.dart';
import 'package:timeline/services/auth_session_manager.dart';

// Manual mock for AuthSessionManager - extends ChangeNotifier for full compatibility
class MockAuthSessionManager extends ChangeNotifier implements AuthSessionManager {
  String? _accessToken;
  bool _shouldRefreshSucceed = true;
  AuthState _state = AuthState.signedOut;
  String? _errorMessage;
  
  void setAccessToken(String? token) {
    _accessToken = token;
    _state = token != null ? AuthState.signedIn : AuthState.signedOut;
  }
  void setRefreshSuccess(bool success) => _shouldRefreshSucceed = success;
  
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

void main() {
  group('NotesyncClient', () {
    late MockAuthSessionManager mockAuthManager;
    late NotesyncClient client;

    setUp(() {
      mockAuthManager = MockAuthSessionManager();
    });

    group('SyncNotePayload', () {
      test('toJson() serializes all fields', () {
        final payload = SyncNotePayload(
          id: 'note-123',
          text: 'Test note',
          isPinned: true,
          tags: ['tag1', 'tag2'],
          createdAt: DateTime.parse('2024-01-15T10:30:00Z'),
          updatedAt: DateTime.parse('2024-01-16T14:20:00Z'),
        );

        final json = payload.toJson();

        expect(json['id'], 'note-123');
        expect(json['text'], 'Test note');
        expect(json['isPinned'], true);
        expect(json['tags'], ['tag1', 'tag2']);
        expect(json['createdAt'], '2024-01-15T10:30:00.000Z');
        expect(json['updatedAt'], '2024-01-16T14:20:00.000Z');
        expect(json.containsKey('deletedAt'), false);
      });

      test('toJson() includes deletedAt when set', () {
        final payload = SyncNotePayload(
          id: 'note-123',
          text: 'Deleted note',
          isPinned: false,
          tags: [],
          createdAt: DateTime.parse('2024-01-15T10:30:00Z'),
          updatedAt: DateTime.parse('2024-01-16T14:20:00Z'),
          deletedAt: DateTime.parse('2024-01-17T09:00:00Z'),
        );

        final json = payload.toJson();

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

        final payload = SyncNotePayload.fromJson(json);

        expect(payload.id, 'note-123');
        expect(payload.text, 'Test note');
        expect(payload.isPinned, true);
        expect(payload.tags, ['tag1', 'tag2']);
        expect(payload.deletedAt, isNull);
      });
    });

    group('SyncMediaPayload', () {
      test('toJson() serializes all fields', () {
        final payload = SyncMediaPayload(
          id: 'media-123',
          noteId: 'note-456',
          kind: 'image',
          filename: 'photo.jpg',
          contentType: 'image/jpeg',
          checksum: 'abc123',
          dataBase64: 'SGVsbG8=',
        );

        final json = payload.toJson();

        expect(json['id'], 'media-123');
        expect(json['noteId'], 'note-456');
        expect(json['kind'], 'image');
        expect(json['filename'], 'photo.jpg');
        expect(json['contentType'], 'image/jpeg');
        expect(json['checksum'], 'abc123');
        expect(json['dataBase64'], 'SGVsbG8=');
      });

      test('fromJson() parses all fields', () {
        final json = {
          'id': 'media-123',
          'noteId': 'note-456',
          'kind': 'audio',
          'filename': 'recording.m4a',
          'contentType': 'audio/m4a',
          'checksum': 'xyz789',
          'dataBase64': 'AAEC',
        };

        final payload = SyncMediaPayload.fromJson(json);

        expect(payload.id, 'media-123');
        expect(payload.noteId, 'note-456');
        expect(payload.kind, 'audio');
        expect(payload.filename, 'recording.m4a');
      });
    });

    group('sendSync()', () {
      test('throws when not authenticated', () async {
        mockAuthManager.setAccessToken(null);
        
        client = NotesyncClient(authManager: mockAuthManager);
        final request = SyncRequest(ops: []);

        expect(
          () => client.sendSync(request),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Not authenticated'))),
        );
        
        client.dispose();
      });

      test('sends request with correct headers', () async {
        String? capturedBody;
        Map<String, String>? capturedHeaders;

        final mockClient = MockClient((request) async {
          capturedBody = request.body;
          capturedHeaders = request.headers;
          return http.Response(
            '{"results": []}',
            200,
          );
        });

        mockAuthManager.setAccessToken('test-token');

        client = NotesyncClient(
          authManager: mockAuthManager,
          httpClient: mockClient,
        );

        final syncRequest = SyncRequest(ops: [
          SyncOperationPayload(
            opId: 'op-1',
            opType: 'create',
            note: SyncNotePayload(
              id: 'note-1',
              text: 'Test',
              isPinned: false,
              tags: [],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ),
        ]);

        await client.sendSync(syncRequest);

        expect(capturedHeaders?['Content-Type'], 'application/json');
        expect(capturedHeaders?['Authorization'], 'Bearer test-token');
        expect(capturedHeaders?['X-API-Key'], isNotNull);
        expect(capturedBody, isNotNull);
        
        final decodedBody = json.decode(capturedBody!);
        expect(decodedBody['ops'], isA<List>());
        expect(decodedBody['ops'].length, 1);
        
        client.dispose();
      });

      test('parses successful response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            json.encode({
              'results': [
                {
                  'noteId': 'note-1',
                  'result': 'created',
                  'note': {
                    'id': 'note-1',
                    'text': 'Test',
                    'isPinned': false,
                    'tags': [],
                    'createdAt': '2024-01-15T10:30:00.000Z',
                    'updatedAt': '2024-01-15T10:30:00.000Z',
                  },
                },
              ],
            }),
            200,
          );
        });

        mockAuthManager.setAccessToken('test-token');

        client = NotesyncClient(
          authManager: mockAuthManager,
          httpClient: mockClient,
        );

        final response = await client.sendSync(SyncRequest(ops: []));

        expect(response.results.length, 1);
        expect(response.results[0].noteId, 'note-1');
        expect(response.results[0].result, 'created');
        
        client.dispose();
      });

      test('retries on 401 with token refresh', () async {
        int callCount = 0;
        
        final mockClient = MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            return http.Response('Unauthorized', 401);
          }
          return http.Response('{"results": []}', 200);
        });

        mockAuthManager.setAccessToken('old-token');
        mockAuthManager.setRefreshSuccess(true);

        client = NotesyncClient(
          authManager: mockAuthManager,
          httpClient: mockClient,
        );

        await client.sendSync(SyncRequest(ops: []));

        expect(callCount, 2);
        
        client.dispose();
      });

      test('throws on non-200 response', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });

        mockAuthManager.setAccessToken('test-token');

        client = NotesyncClient(
          authManager: mockAuthManager,
          httpClient: mockClient,
        );

        expect(
          () => client.sendSync(SyncRequest(ops: [])),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('500'))),
        );
        
        client.dispose();
      });
    });

    group('fetchLatestNotes()', () {
      test('throws when not authenticated', () async {
        mockAuthManager.setAccessToken(null);
        
        client = NotesyncClient(authManager: mockAuthManager);

        expect(
          () => client.fetchLatestNotes(),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Not authenticated'))),
        );
        
        client.dispose();
      });

      test('parses notes and media from response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            json.encode({
              'notes': [
                {
                  'id': 'note-1',
                  'text': 'Test note',
                  'isPinned': false,
                  'tags': ['tag1'],
                  'createdAt': '2024-01-15T10:30:00.000Z',
                  'updatedAt': '2024-01-15T10:30:00.000Z',
                },
              ],
              'media': [
                {
                  'id': 'media-1',
                  'noteId': 'note-1',
                  'kind': 'image',
                  'filename': 'photo.jpg',
                  'contentType': 'image/jpeg',
                  'checksum': 'abc123',
                  'dataBase64': 'SGVsbG8=',
                },
              ],
            }),
            200,
          );
        });

        mockAuthManager.setAccessToken('test-token');

        client = NotesyncClient(
          authManager: mockAuthManager,
          httpClient: mockClient,
        );

        final response = await client.fetchLatestNotes();

        expect(response.notes.length, 1);
        expect(response.notes[0].id, 'note-1');
        expect(response.notes[0].text, 'Test note');
        expect(response.media.length, 1);
        expect(response.media[0].id, 'media-1');
        expect(response.media[0].kind, 'image');
        
        client.dispose();
      });

      test('handles empty media array', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            json.encode({
              'notes': [],
            }),
            200,
          );
        });

        mockAuthManager.setAccessToken('test-token');

        client = NotesyncClient(
          authManager: mockAuthManager,
          httpClient: mockClient,
        );

        final response = await client.fetchLatestNotes();

        expect(response.notes, isEmpty);
        expect(response.media, isEmpty);
        
        client.dispose();
      });
    });
  });
}
