// lib/features/object_detection/application/object_detection_service.dart
//
// The single entry point the rest of the app uses for object detection.
//
// Usage
// ─────
//   final service = ObjectDetectionService.onDevice(classNames: myLabels);
//   await service.init();
//
//   final results = await service.detect(myImage);
//   // results is List<DetectionResult> — same type regardless of backend
//
//   service.dispose(); // call when done (e.g. in widget dispose())
//
// When you add the remote backend later, just swap the constructor:
//   final service = ObjectDetectionService.remote(baseUrl: '...');
// Everything else stays the same.

import 'package:image/image.dart' as img;

import 'package:baseer/features/analysis/domain/detected_object.dart';

import '../domain/detection_result.dart';
import '../domain/object_detector.dart';
import 'on_device_object_detector.dart';

// ── Future import (uncomment when backend is ready) ───────────────────────────
// import 'remote_object_detector.dart';

class ObjectDetectionService {
  final ObjectDetector _detector;

  ObjectDetectionService._(this._detector);

  // ── Factory constructors ───────────────────────────────────────────────────

  /// On-device inference via the bundled ONNX model.
  ///
  /// [classNames] must match the class order your model was trained with.
  /// [modelAssetPath] defaults to 'assets/ml/model.onnx'.
  factory ObjectDetectionService.onDevice({
    required List<String> classNames,
    String modelAssetPath = 'assets/ml/model.onnx',
    int inputSize = 640,
    double confidenceThreshold = 0.5,
    double iouThreshold = 0.45,
  }) {
    return ObjectDetectionService._(
      OnDeviceObjectDetector(
        classNames: classNames,
        modelAssetPath: modelAssetPath,
        inputSize: inputSize,
        confidenceThreshold: confidenceThreshold,
        iouThreshold: iouThreshold,
      ),
    );
  }

  // ── Future factory (uncomment when backend is ready) ──────────────────────
  //
  // factory ObjectDetectionService.remote({required String baseUrl}) {
  //   return ObjectDetectionService._(RemoteObjectDetector(baseUrl: baseUrl));
  // }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Initialise the underlying detector.  Must be awaited once before [detect].
  Future<void> init() => _detector.init();

  /// Detect objects in [image].
  ///
  /// Returns a list sorted by confidence (highest first).
  /// Returns an empty list if nothing is detected.
  Future<List<DetectionResult>> detect(img.Image image) =>
      _detector.detect(image);

  /// Returns detections as the shared [DetectedObject] type.
  /// Color and distance are empty — filled in by other modules.
  Future<List<DetectedObject>> detectObjects(img.Image image) async {
    final results = await _detector.detect(image);
    return results
        .map(
          (r) => DetectedObject.fromDetectionResult(
            label: r.label,
            confidence: r.confidence,
            x1: r.boundingBox.x1.round(),
            y1: r.boundingBox.y1.round(),
            x2: r.boundingBox.x2.round(),
            y2: r.boundingBox.y2.round(),
          ),
        )
        .toList();
  }

  /// Release all resources.  Call from your widget's dispose() or equivalent.
  void dispose() => _detector.dispose();
}
