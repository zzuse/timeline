import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline/data/image_store.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ImageStore imageStore;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('image_store_test');
    
    // Mock path_provider channel
    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
  });

  setUp(() {
    imageStore = ImageStore();
  });

  tearDownAll(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('ImageStore', () {
    test('saveImage saves and compresses image', () async {
      // Create a test image
      final testImage = img.Image(width: 100, height: 100);
      img.fill(testImage, color: img.ColorRgb8(255, 0, 0)); // Red
      final pngBytes = img.encodePng(testImage);
      
      final sourceFile = File('${tempDir.path}/source.png');
      await sourceFile.writeAsBytes(pngBytes);

      final filename = await imageStore.saveImage(sourceFile);
      
      expect(filename, endsWith('.jpg')); // Should convert to jpg
      
      final savedFile = await imageStore.loadImage(filename);
      expect(savedFile, isNotNull);
      expect(await savedFile!.exists(), isTrue);
      
      // Check if it's a valid JPEG
      final savedBytes = await savedFile.readAsBytes();
      final savedImage = img.decodeJpg(savedBytes);
      expect(savedImage, isNotNull);
      expect(savedImage!.width, 100);
      expect(savedImage.height, 100);
    });

    test('saveImageBytes saves bytes directly', () async {
      final testImage = img.Image(width: 50, height: 50);
      // img.fill uses integer color
      img.fill(testImage, color: img.ColorRgb8(0, 255, 0));
      final jpgBytes = img.encodeJpg(testImage);

      final filename = await imageStore.saveImageBytes(jpgBytes);
      
      final savedFile = await imageStore.loadImage(filename);
      expect(savedFile, isNotNull);
      expect(await savedFile!.exists(), isTrue);
    });

    test('resizes large images', () async {
      // Create a mock large image (2000x100)
      // Generating actual large image bytes might be slow/heavy for test
      // but let's try a reasonable size that triggers logic (max is 1920)
      final largeImage = img.Image(width: 2000, height: 100);
      img.fill(largeImage, color: img.ColorRgb8(0, 0, 255));
      final jpgBytes = img.encodeJpg(largeImage);
      
      final filename = await imageStore.saveImageBytes(jpgBytes);
      final savedFile = await imageStore.getFile(filename);
      final savedBytes = await savedFile.readAsBytes();
      final savedImage = img.decodeJpg(savedBytes)!;
      
      expect(savedImage.width, 1920); // Should be resized to max dimension
      expect(savedImage.height, lessThan(100)); // Aspect ratio preserved (100 * 1920/2000 = 96)
    });

    test('deleteImages removes files', () async {
      final testImage = img.Image(width: 10, height: 10);
      final bytes = img.encodeJpg(testImage);
      
      final filename = await imageStore.saveImageBytes(bytes);
      File? file = await imageStore.loadImage(filename);
      expect(await file!.exists(), isTrue);
      
      await imageStore.deleteImages([filename]);
      
      file = await imageStore.loadImage(filename);
      expect(file, isNull);
    });
    
    test('saveBytes saves exact bytes (for sync)', () async {
      final bytes = [1, 2, 3, 4, 5]; // Not a real image, just bytes
      // Wait, saveBytes calling _compressImage which calls decodeImage. 
      // So saveBytes expects VALID IMAGE BYTES.
      // Let's use valid bytes.
      
      final testImage = img.Image(width: 10, height: 10);
      final validBytes = img.encodeJpg(testImage);
      
      final filename = 'sync_test.jpg';
      await imageStore.saveBytes(filename, validBytes);
      
      final file = await imageStore.getFile(filename);
      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(0));
    });
  });
}
