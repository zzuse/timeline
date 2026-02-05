import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Store and manage audio files
class AudioStore {
  static const _folderName = 'Audio';
  static final _uuid = Uuid();

  Future<Directory> get _baseDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${appDir.path}/$_folderName');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return audioDir;
  }

  /// Create a new recording file path and return (fullPath, filename)
  Future<({String path, String filename})> makeRecordingPath() async {
    final dir = await _baseDir;
    final filename = '${_uuid.v4()}.m4a';
    final path = '${dir.path}/$filename';
    return (path: path, filename: filename);
  }

  /// Get the full path for an audio filename
  Future<String> getAudioPath(String filename) async {
    final dir = await _baseDir;
    return '${dir.path}/$filename';
  }

  /// Check if audio file exists
  Future<bool> audioExists(String filename) async {
    final path = await getAudioPath(filename);
    return File(path).exists();
  }

  /// Delete audio files
  Future<void> deleteAudios(List<String> filenames) async {
    final dir = await _baseDir;
    for (final filename in filenames) {
      final file = File('${dir.path}/$filename');
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  /// Save audio bytes with specific filename (for sync)
  Future<void> saveBytes(String filename, List<int> bytes) async {
    final dir = await _baseDir;
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
  }

  /// Get File object for a specific filename (for sync)
  Future<File> getFile(String filename) async {
    final path = await getAudioPath(filename);
    return File(path);
  }

  /// Get URL for a specific filename (for compatibility with iOS)
  Future<String> url({required String for_}) async {
    return await getAudioPath(for_);
  }
}
