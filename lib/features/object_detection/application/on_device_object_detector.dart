import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

import '../domain/detection_result.dart';
import '../domain/object_detector.dart';

class OnDeviceObjectDetector implements ObjectDetector {
  final List<String> classNames;
  final String modelAssetPath;
  final int inputSize;
  final double confidenceThreshold;
  final double iouThreshold;

  OrtSession? _session;

  OnDeviceObjectDetector({
    required this.classNames,
    this.modelAssetPath = 'assets/ml/yolov8n_int8.onnx',
    this.inputSize = 640,
    this.confidenceThreshold = 0.5,
    this.iouThreshold = 0.45,
  });

  @override
  Future<void> init() async {
    OrtEnv.instance.init();
    final ByteData assetData = await rootBundle.load(modelAssetPath);
    final Uint8List modelBytes = assetData.buffer.asUint8List();
    final opts = OrtSessionOptions();
    _session = OrtSession.fromBuffer(modelBytes, opts);
  }

  @override
  Future<List<DetectionResult>> detect(img.Image image) async {
    if (_session == null) throw StateError('Call init() before detect().');
    final preprocessed = await compute(
      _preprocessIsolate,
      _PreprocessInput(
        rgbaBytes: image.getBytes(order: img.ChannelOrder.rgba),
        originalWidth: image.width,
        originalHeight: image.height,
        inputSize: inputSize,
      ),
    );

    final inputTensor = OrtValueTensor.createTensorWithDataList(
      preprocessed.data,
      [1, 3, inputSize, inputSize],
    );

    final inputs = {_session!.inputNames[0]: inputTensor};
    final runOptions = OrtRunOptions();
    final outputs = await _session!.runAsync(runOptions, inputs);
    inputTensor.release();
    runOptions.release();

    if (outputs == null || outputs.isEmpty || outputs[0] == null) {
      return [];
    }

    final rawOutput = outputs[0]!.value as List;
    final results = _postprocess(
      rawOutput,
      image.width,
      image.height,
      preprocessed.scale,
      preprocessed.padLeft,
      preprocessed.padTop,
    );

    for (final output in outputs) {
      output?.release();
    }

    return results;
  }

  @override
  void dispose() {
    _session?.release();
    OrtEnv.instance.release();
    _session = null;
  }

  List<DetectionResult> _postprocess(
    List rawOutput,
    int originalWidth,
    int originalHeight,
    double scale,
    int padLeft,
    int padTop,
  ) {
    final List predictions = rawOutput[0] as List;
    final int numRows = predictions.length;
    final int numAnchors = (predictions[0] as List).length;
    final int numClasses = numRows - 4;

    final List<_RawDetection> candidates = [];

    for (int i = 0; i < numAnchors; i++) {
      double maxScore = 0.0;
      int bestClass = 0;
      for (int c = 0; c < numClasses; c++) {
        final double score = (predictions[4 + c] as List)[i].toDouble();
        if (score > maxScore) {
          maxScore = score;
          bestClass = c;
        }
      }

      if (maxScore < confidenceThreshold) continue;

      final double xCentre = (predictions[0] as List)[i].toDouble();
      final double yCentre = (predictions[1] as List)[i].toDouble();
      final double width = (predictions[2] as List)[i].toDouble();
      final double height = (predictions[3] as List)[i].toDouble();

      final double x1 = ((xCentre - width / 2 - padLeft) / scale).clamp(
        0.0,
        originalWidth.toDouble(),
      );
      final double y1 = ((yCentre - height / 2 - padTop) / scale).clamp(
        0.0,
        originalHeight.toDouble(),
      );
      final double x2 = ((xCentre + width / 2 - padLeft) / scale).clamp(
        0.0,
        originalWidth.toDouble(),
      );
      final double y2 = ((yCentre + height / 2 - padTop) / scale).clamp(
        0.0,
        originalHeight.toDouble(),
      );

      candidates.add(
        _RawDetection(
          x1: x1,
          y1: y1,
          x2: x2,
          y2: y2,
          score: maxScore,
          classIndex: bestClass,
        ),
      );
    }

    final Map<int, List<_RawDetection>> byClass = {};
    for (final candidate in candidates) {
      byClass.putIfAbsent(candidate.classIndex, () => []).add(candidate);
    }

    final List<DetectionResult> results = [];
    for (final entry in byClass.entries) {
      final kept = _nms(entry.value);
      for (final detection in kept) {
        final String label = entry.key < classNames.length
            ? classNames[entry.key]
            : 'class_${entry.key}';
        results.add(
          DetectionResult(
            label: label,
            confidence: detection.score,
            boundingBox: BoundingBox(
              x1: detection.x1,
              y1: detection.y1,
              x2: detection.x2,
              y2: detection.y2,
            ),
          ),
        );
      }
    }

    results.sort(
      (detection1, detection2) =>
          detection2.confidence.compareTo(detection1.confidence),
    );
    return results;
  }

  List<_RawDetection> _nms(List<_RawDetection> detections) {
    detections.sort(
      (detection1, detection2) => detection2.score.compareTo(detection1.score),
    );
    final suppressed = List.filled(detections.length, false);
    final kept = <_RawDetection>[];

    for (int i = 0; i < detections.length; i++) {
      if (suppressed[i]) continue;
      kept.add(detections[i]);
      for (int j = i + 1; j < detections.length; j++) {
        if (suppressed[j]) continue;
        if (_iou(detections[i], detections[j]) > iouThreshold) {
          suppressed[j] = true;
        }
      }
    }
    return kept;
  }

  double _iou(_RawDetection a, _RawDetection b) {
    final double intersectionX1 = a.x1 > b.x1 ? a.x1 : b.x1;
    final double intersectionY1 = a.y1 > b.y1 ? a.y1 : b.y1;
    final double intersectionX2 = a.x2 < b.x2 ? a.x2 : b.x2;
    final double intersectionY2 = a.y2 < b.y2 ? a.y2 : b.y2;
    final double intersectionWidth = intersectionX2 - intersectionX1;
    final double intersectionHeight = intersectionY2 - intersectionY1;
    if (intersectionWidth <= 0 || intersectionHeight <= 0) {
      return 0.0;
    }
    final double intersectionArea = intersectionWidth * intersectionHeight;
    final double unionArea =
        (a.x2 - a.x1) * (a.y2 - a.y1) +
        (b.x2 - b.x1) * (b.y2 - b.y1) -
        intersectionArea;
    return intersectionArea / unionArea;
  }
}

class _RawDetection {
  final double x1, y1, x2, y2, score;
  final int classIndex;
  const _RawDetection({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.score,
    required this.classIndex,
  });
}

class _PreprocessInput {
  final Uint8List rgbaBytes;
  final int originalWidth;
  final int originalHeight;
  final int inputSize;
  const _PreprocessInput({
    required this.rgbaBytes,
    required this.originalWidth,
    required this.originalHeight,
    required this.inputSize,
  });
}

class _PreprocessOutput {
  final Float32List data;
  final double scale;
  final int padLeft;
  final int padTop;
  const _PreprocessOutput({
    required this.data,
    required this.scale,
    required this.padLeft,
    required this.padTop,
  });
}

_PreprocessOutput _preprocessIsolate(_PreprocessInput input) {
  final int size = input.inputSize;
  final int originalWidth = input.originalWidth;
  final int originalHeight = input.originalHeight;
  final Uint8List source = input.rgbaBytes;

  final int maxDimension = (originalWidth > originalHeight)
      ? originalWidth
      : originalHeight;
  final double scale = size / maxDimension;
  final int newWidth = (originalWidth * scale).round();
  final int newHeight = (originalHeight * scale).round();
  final int padLeft = (size - newWidth) ~/ 2;
  final int padTop = (size - newHeight) ~/ 2;

  final Float32List output = Float32List(3 * size * size);
  for (int i = 0; i < output.length; i++) {
    output[i] = 0.5;
  }

  for (int y = 0; y < newHeight; y++) {
    final double sourceY = y / scale;
    final int topRow = sourceY.floor().clamp(0, originalHeight - 1);
    final int bottomRow = (topRow + 1).clamp(0, originalHeight - 1);
    final double yWeight = sourceY - topRow;

    for (int x = 0; x < newWidth; x++) {
      final double sourceX = x / scale;
      final int topColumn = sourceX.floor().clamp(0, originalWidth - 1);
      final int bottomColumn = (topColumn + 1).clamp(0, originalWidth - 1);
      final double xWeight = sourceX - topColumn;

      final int topLeftIndex = (topRow * originalWidth + topColumn) * 4;
      final int topRightIndex = (topRow * originalWidth + bottomColumn) * 4;
      final int bottomLeftIndex = (bottomRow * originalWidth + topColumn) * 4;
      final int bottomRightIndex =
          (bottomRow * originalWidth + bottomColumn) * 4;

      for (int colour = 0; colour < 3; colour++) {
        final double v =
            (source[topLeftIndex + colour] * (1 - xWeight) +
                    source[topRightIndex + colour] * xWeight) *
                (1 - yWeight) +
            (source[bottomLeftIndex + colour] * (1 - xWeight) +
                    source[bottomRightIndex + colour] * xWeight) *
                yWeight;

        final int destY = padTop + y;
        final int destX = padLeft + x;
        output[colour * size * size + destY * size + destX] = v / 255.0;
      }
    }
  }

  return _PreprocessOutput(
    data: output,
    scale: scale,
    padLeft: padLeft,
    padTop: padTop,
  );
}
