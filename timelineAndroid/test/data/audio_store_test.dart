import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline/data/audio_store.dart';
import 'package:path_provider/path_provider.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Mock path_provider
  const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory testDir;

  setUpAll(() async {
    testDir = await Directory.systemTemp.createTemp('audio_test_');
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return testDir.path;
    });
  });

  tearDownAll(() {
    testDir.deleteSync(recursive: true);
  });

  group('AudioStore', () {
    late AudioStore audioStore;

    setUp(() async {
      audioStore = AudioStore();
      // No init() needed
    });

    test('makeRecordingPath creates a valid path', () async {
      final result = await audioStore.makeRecordingPath();
      
      expect(result.path, contains(testDir.path));
      expect(result.filename, endsWith('.m4a'));
      expect(path.basename(result.path), equals(result.filename));
    });

    test('saveBytes saves audio file', () async {
      final bytes = [10, 20, 30, 40];
      final filename = 'test_audio.m4a';
      
      await audioStore.saveBytes(filename, bytes);
      
      final file = await audioStore.getFile(filename);
      expect(await file.exists(), isTrue);
      
      final savedBytes = await file.readAsBytes();
      expect(savedBytes, equals(bytes));
    });

    test('audioExists returns correct status', () async {
      final filename = 'exists.m4a';
      await audioStore.saveBytes(filename, [1, 2, 3]);
      
      expect(await audioStore.audioExists(filename), isTrue);
      expect(await audioStore.audioExists('non_existent.m4a'), isFalse);
    });

    test('deleteAudios removes files', () async {
      final filename = 'delete_me.m4a';
      await audioStore.saveBytes(filename, [1, 2, 3]);
      expect(await audioStore.audioExists(filename), isTrue);
      
      await audioStore.deleteAudios([filename]);
      
      expect(await audioStore.audioExists(filename), isFalse);
    });

    test('getAudioPath returns full path', () async {
      final filename = 'path_test.m4a';
      await audioStore.saveBytes(filename, [0]);
      
      final fullPath = await audioStore.getAudioPath(filename);
      expect(fullPath, equals(path.join(testDir.path, 'Audio', filename))); // Fixed path assertion
    });
  });
}
