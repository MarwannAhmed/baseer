// lib/features/object_detection/domain/object_detector.dart
//
// The "black box" contract every detector implementation must satisfy.
// On-device (ONNX) and remote (FastAPI) detectors both implement this.
// Callers never import a concrete class — only this interface.

import 'package:image/image.dart' as img;
import 'detection_result.dart';

abstract class ObjectDetector {
  /// One-time setup: load the model, open HTTP client, etc.
  /// Must be awaited before calling [detect].
  Future<void> init();

  /// Run detection on a decoded [img.Image].
  /// Returns an empty list (not null) when nothing is found.
  Future<List<DetectionResult>> detect(img.Image image);

  /// Release all resources (model session, HTTP client, etc.).
  void dispose();
}