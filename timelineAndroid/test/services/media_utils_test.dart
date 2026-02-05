import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline/services/media_utils.dart';

void main() {
  group('MediaUtils', () {
    late Directory tempDir;
    late File testFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('media_utils_test_');
      testFile = File('${tempDir.path}/test.txt');
      await testFile.writeAsString('Hello, World!');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('calculateChecksum()', () {
      test('returns consistent SHA256 hash for same content', () async {
        final checksum1 = await MediaUtils.calculateChecksum(testFile);
        final checksum2 = await MediaUtils.calculateChecksum(testFile);
        
        expect(checksum1, equals(checksum2));
        expect(checksum1.length, equals(64)); // SHA256 hex string length
      });

      test('returns different hash for different content', () async {
        final file2 = File('${tempDir.path}/test2.txt');
        await file2.writeAsString('Different content');
        
        final checksum1 = await MediaUtils.calculateChecksum(testFile);
        final checksum2 = await MediaUtils.calculateChecksum(file2);
        
        expect(checksum1, isNot(equals(checksum2)));
      });

      test('returns known hash for known content', () async {
        // SHA256 of "Hello, World!" is known
        final checksum = await MediaUtils.calculateChecksum(testFile);
        expect(checksum, equals('dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f'));
      });
    });

    group('encodeFileToBase64()', () {
      test('correctly encodes file to Base64', () async {
        final base64 = await MediaUtils.encodeFileToBase64(testFile);
        
        // "Hello, World!" in Base64
        expect(base64, equals('SGVsbG8sIFdvcmxkIQ=='));
      });

      test('encodes binary file correctly', () async {
        final binaryFile = File('${tempDir.path}/binary.bin');
        await binaryFile.writeAsBytes([0x00, 0x01, 0x02, 0xFF]);
        
        final base64 = await MediaUtils.encodeFileToBase64(binaryFile);
        expect(base64, equals('AAEC/w=='));
      });
    });

    group('decodeBase64ToBytes()', () {
      test('correctly decodes Base64 to bytes', () {
        final bytes = MediaUtils.decodeBase64ToBytes('SGVsbG8sIFdvcmxkIQ==');
        
        expect(String.fromCharCodes(bytes), equals('Hello, World!'));
      });

      test('decodes binary data correctly', () {
        final bytes = MediaUtils.decodeBase64ToBytes('AAEC/w==');
        
        expect(bytes, equals([0x00, 0x01, 0x02, 0xFF]));
      });

      test('round-trip encode/decode preserves data', () async {
        final originalBytes = [1, 2, 3, 4, 5, 100, 200, 255];
        final file = File('${tempDir.path}/roundtrip.bin');
        await file.writeAsBytes(originalBytes);
        
        final base64 = await MediaUtils.encodeFileToBase64(file);
        final decoded = MediaUtils.decodeBase64ToBytes(base64);
        
        expect(decoded, equals(originalBytes));
      });
    });

    group('getContentType()', () {
      group('image types', () {
        test('returns image/jpeg for .jpg files', () {
          expect(MediaUtils.getContentType('image', 'photo.jpg'), 'image/jpeg');
          expect(MediaUtils.getContentType('image', 'photo.JPG'), 'image/jpeg');
        });

        test('returns image/png for .png files', () {
          expect(MediaUtils.getContentType('image', 'icon.png'), 'image/png');
          expect(MediaUtils.getContentType('image', 'icon.PNG'), 'image/png');
        });

        test('defaults to image/jpeg for unknown image extensions', () {
          expect(MediaUtils.getContentType('image', 'photo.webp'), 'image/jpeg');
          expect(MediaUtils.getContentType('image', 'photo'), 'image/jpeg');
        });
      });

      group('audio types', () {
        test('returns audio/mpeg for .mp3 files', () {
          expect(MediaUtils.getContentType('audio', 'music.mp3'), 'audio/mpeg');
          expect(MediaUtils.getContentType('audio', 'music.MP3'), 'audio/mpeg');
        });

        test('returns audio/wav for .wav files', () {
          expect(MediaUtils.getContentType('audio', 'sound.wav'), 'audio/wav');
        });

        test('defaults to audio/m4a for unknown audio extensions', () {
          expect(MediaUtils.getContentType('audio', 'recording.m4a'), 'audio/m4a');
          expect(MediaUtils.getContentType('audio', 'recording.aac'), 'audio/m4a');
        });
      });

      test('returns application/octet-stream for unknown kinds', () {
        expect(MediaUtils.getContentType('video', 'movie.mp4'), 'application/octet-stream');
        expect(MediaUtils.getContentType('document', 'file.pdf'), 'application/octet-stream');
      });
    });

    group('validateChecksum()', () {
      test('returns true for matching checksum', () async {
        final checksum = await MediaUtils.calculateChecksum(testFile);
        final isValid = await MediaUtils.validateChecksum(testFile, checksum);
        
        expect(isValid, isTrue);
      });

      test('returns false for non-matching checksum', () async {
        final isValid = await MediaUtils.validateChecksum(testFile, 'invalid-checksum');
        
        expect(isValid, isFalse);
      });
    });

    group('getFileSize()', () {
      test('returns correct file size', () async {
        // "Hello, World!" is 13 bytes
        final size = await MediaUtils.getFileSize(testFile);
        
        expect(size, equals(13));
      });

      test('returns correct size for binary file', () async {
        final binaryFile = File('${tempDir.path}/binary.bin');
        await binaryFile.writeAsBytes(List.generate(100, (i) => i));
        
        final size = await MediaUtils.getFileSize(binaryFile);
        
        expect(size, equals(100));
      });
    });
  });
}
