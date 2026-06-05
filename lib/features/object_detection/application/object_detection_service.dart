import 'package:image/image.dart' as img;

import 'package:baseer/features/analysis/domain/detected_object.dart';

import '../domain/detection_result.dart';
import '../domain/object_detector.dart';
import 'on_device_object_detector.dart';
import 'remote_object_detector.dart';

class ObjectDetectionService {
  final ObjectDetector _detector;

  ObjectDetectionService._(this._detector);

  factory ObjectDetectionService.onDevice({
    required List<String> classNames,
    String modelAssetPath = 'assets/ml/yolov8n_int8.onnx',
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

  factory ObjectDetectionService.remote({required String baseUrl}) {
    return ObjectDetectionService._(RemoteObjectDetector(baseUrl: baseUrl));
  }

  Future<void> init() => _detector.init();

  Future<List<DetectionResult>> detect(img.Image image) =>
      _detector.detect(image);

  Future<List<DetectedObject>> detectObjects(img.Image image) async {
    final results = await _detector.detect(image);
    return results
        .map(
          (result) => DetectedObject.fromDetectionResult(
            label: result.label,
            confidence: result.confidence,
            x1: result.boundingBox.x1.round(),
            y1: result.boundingBox.y1.round(),
            x2: result.boundingBox.x2.round(),
            y2: result.boundingBox.y2.round(),
          ),
        )
        .toList();
  }

  void dispose() => _detector.dispose();
}
