import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

/// Utilities for media file handling in sync operations
class MediaUtils {
  /// Calculate SHA256 checksum for a file
  static Future<String> calculateChecksum(File file) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Encode file to base64 string
  static Future<String> encodeFileToBase64(File file) async {
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  /// Decode base64 string to bytes
  static List<int> decodeBase64ToBytes(String base64String) {
    return base64Decode(base64String);
  }

  /// Get content type for media files
  static String getContentType(String kind, String filename) {
    if (kind == 'image') {
      if (filename.toLowerCase().endsWith('.png')) {
        return 'image/png';
      }
      return 'image/jpeg'; // Default for images
    } else if (kind == 'audio') {
      if (filename.toLowerCase().endsWith('.mp3')) {
        return 'audio/mpeg';
      }
      if (filename.toLowerCase().endsWith('.wav')) {
        return 'audio/wav';
      }
      return 'audio/m4a'; // Default for audio
    }
    return 'application/octet-stream';
  }

  /// Validate checksum matches
  static Future<bool> validateChecksum(File file, String expectedChecksum) async {
    final actualChecksum = await calculateChecksum(file);
    return actualChecksum == expectedChecksum;
  }

  /// Get file size in bytes
  static Future<int> getFileSize(File file) async {
    return await file.length();
  }
}
