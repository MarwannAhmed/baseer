import 'package:image/image.dart' as img;

import '../domain/detection_result.dart';
import '../domain/object_detector.dart';
import 'on_device_object_detector.dart';

class ObjectDetectionService {
  final ObjectDetector _detector;

  ObjectDetectionService._(this._detector);

  factory ObjectDetectionService.onDevice({
    required List<String> classNames,
    String modelPath = 'assets/ml/model.onnx',
    int inputSize = 640,
    double confidenceThreshold = 0.5,
    double iouThreshold = 0.45,
  }) {
    return ObjectDetectionService._(
      OnDeviceObjectDetector(
        classNames: classNames,
        modelPath: modelPath,
        inputSize: inputSize,
        confidenceThreshold: confidenceThreshold,
        iouThreshold: iouThreshold,
      ),
    );
  }

  Future<void> init() => _detector.init();

  Future<List<DetectionResult>> detect(img.Image image) =>
      _detector.detect(image);

  void dispose() => _detector.dispose();
}
