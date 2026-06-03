// Dart on-device replacement for infer_color_onnx.py
// Usage (debug):
//   flutter run -t lib/tools/infer_color_onnx.dart --debug
// Or call `inferImageFile(path)` from an existing debug UI in the app.

import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;
import 'package:baseer/features/color_recognition/application/color_detector_svm.dart';

/// Infer the color for a single image file using the on-device ONNX SVM.
/// Returns the English label (e.g. 'red') or 'error'.
Future<String> inferImageFile(String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    final img.Image? image = img.decodeImage(bytes);
    if (image == null) {
      print('[infer] Failed to decode image: $path');
      return 'error';
    }

    // Ensure the classifier is initialised.
    await SvmColorClassifier.instance.init();

    // Use ColorDetectorSvm to process the whole image and return a result.
    final ColorDetectorSvm detector = ColorDetectorSvm();
    await detector.setFrame(image);
    final result = detector.detect(0, 0, image.width, image.height);
    print('[infer] $path → ${result.colorEn} / ${result.colorAr}');
    return result.colorEn;
  } catch (e) {
    print('[infer] Error: $e');
    return 'error';
  }
}

/// Minimal headless entrypoint for `flutter run -t lib/tools/infer_color_onnx.dart`.
/// It looks for a folder named `test_images` in the app's working directory
/// (for desktop runs) or expects the path(s) passed via environment variable
/// `INFER_IMAGES` when building for device with `--dart-define`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Try to read image paths from the INFER_IMAGES dart-define (semicolon-separated).
  const env = String.fromEnvironment('INFER_IMAGES', defaultValue: '');
  List<String> paths = [];
  if (env.isNotEmpty) paths = env.split(';').where((s) => s.isNotEmpty).toList();

  // If none provided, look for a local ./test_images directory (useful for desktop runs).
  if (paths.isEmpty) {
    final dir = Directory('test_images');
    if (await dir.exists()) {
      paths = dir
          .listSync()
          .whereType<File>()
          .where((f) => ['.jpg', '.jpeg', '.png', '.bmp'].contains(f.path.toLowerCase().split('.').last))
          .map((f) => f.path)
          .toList();
    }
  }

  if (paths.isEmpty) {
    print('No images found. Provide paths via --dart-define=INFER_IMAGES=path1;path2 or place images in ./test_images');
    return;
  }

  for (final p in paths) {
    await inferImageFile(p);
  }
}
