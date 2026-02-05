import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;

/// Store and manage image files
class ImageStore {
  static const _folderName = 'Images';
  static final _uuid = Uuid();
  
  // Match iOS compression quality (0.82)
  static const _jpegQuality = 82;
  // Max dimension for resizing (improves on iOS by preventing huge files)
  static const _maxDimension = 1920;

  Future<Directory> get _baseDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final imageDir = Directory('${appDir.path}/$_folderName');
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    return imageDir;
  }

  /// Compress image bytes to JPEG at 82% quality (matching iOS)
  /// Also resizes images larger than 1920px to prevent huge uploads
  List<int> _compressImage(List<int> bytes) {
    // Convert to Uint8List for image package
    final uint8bytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    
    var image = img.decodeImage(uint8bytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }
    
    // Resize if too large (while maintaining aspect ratio)
    if (image.width > _maxDimension || image.height > _maxDimension) {
      if (image.width > image.height) {
        image = img.copyResize(image, width: _maxDimension);
      } else {
        image = img.copyResize(image, height: _maxDimension);
      }
    }
    
    return img.encodeJpg(image, quality: _jpegQuality);
  }

  /// Save image file and return the filename
  Future<String> saveImage(File imageFile) async {
    final dir = await _baseDir;
    final filename = '${_uuid.v4()}.jpg';
    
    // Read, compress, and save
    final bytes = await imageFile.readAsBytes();
    final compressedBytes = _compressImage(bytes);
    
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(compressedBytes);
    
    return filename;
  }

  /// Save image from bytes and return the filename
  Future<String> saveImageBytes(List<int> bytes) async {
    final dir = await _baseDir;
    final filename = '${_uuid.v4()}.jpg';
    
    // Compress before saving
    final compressedBytes = _compressImage(bytes);
    
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(compressedBytes);
    
    return filename;
  }

  /// Get the full path for an image filename
  Future<String> getImagePath(String filename) async {
    final dir = await _baseDir;
    return '${dir.path}/$filename';
  }

  /// Load image file by filename
  Future<File?> loadImage(String filename) async {
    final path = await getImagePath(filename);
    final file = File(path);
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  /// Delete image files
  Future<void> deleteImages(List<String> filenames) async {
    final dir = await _baseDir;
    for (final filename in filenames) {
      final file = File('${dir.path}/$filename');
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  /// Save image bytes with specific filename (for sync)
  Future<void> saveBytes(String filename, List<int> bytes) async {
    final dir = await _baseDir;
    
    // Compress before saving
    final compressedBytes = _compressImage(bytes);
    
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(compressedBytes);
  }

  /// Get File object for a specific filename (for sync)
  Future<File> getFile(String filename) async {
    final path = await getImagePath(filename);
    return File(path);
  }

  /// Get URL for a specific filename (for compatibility with iOS)
  Future<String> url({required String for_}) async {
    return await getImagePath(for_);
  }
}
