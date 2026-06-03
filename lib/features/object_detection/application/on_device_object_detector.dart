import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

import '../domain/detection_result.dart';
import '../domain/object_detector.dart';

class OnDeviceObjectDetector implements ObjectDetector {
  final List<String> classNames;
  final String modelPath;
  final int inputSize;
  final double confidenceThreshold;
  final double iouThreshold;

  OrtSession? _session;

  OnDeviceObjectDetector({
    required this.classNames,
    this.modelPath = 'assets/ml/model.onnx',
    this.inputSize = 640,
    this.confidenceThreshold = 0.5,
    this.iouThreshold = 0.45,
  });

  @override
  Future<void> init() async {
    OrtEnv.instance.init();
    final ByteData assetData = await rootBundle.load(modelPath);
    final Uint8List modelBytes = assetData.buffer.asUint8List();
    final opts = OrtSessionOptions();
    _session = OrtSession.fromBuffer(modelBytes, opts);
  }

  @override
  Future<List<DetectionResult>> detect(img.Image image) async {
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

    if (outputs == null || outputs.isEmpty || outputs[0] == null) return [];

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
    final int rowsCount = predictions.length;
    final int anchorsCount = (predictions[0] as List).length;
    final int classesCount = rowsCount - 4;

    final List<_RawDetection> candidates = [];

    for (int i = 0; i < anchorsCount; i++) {
      double maxScore = 0.0;
      int bestClass = 0;
      for (int c = 0; c < classesCount; c++) {
        final double score = (predictions[4 + c] as List)[i].toDouble();
        if (score > maxScore) {
          maxScore = score;
          bestClass = c;
        }
      }

      if (maxScore < confidenceThreshold) continue;

      final double cx = (predictions[0] as List)[i].toDouble();
      final double cy = (predictions[1] as List)[i].toDouble();
      final double width = (predictions[2] as List)[i].toDouble();
      final double height = (predictions[3] as List)[i].toDouble();

      final double x1 = ((cx - width / 2 - padLeft) / scale).clamp(
        0.0,
        originalWidth.toDouble(),
      );
      final double y1 = ((cy - height / 2 - padTop) / scale).clamp(
        0.0,
        originalHeight.toDouble(),
      );
      final double x2 = ((cx + width / 2 - padLeft) / scale).clamp(
        0.0,
        originalWidth.toDouble(),
      );
      final double y2 = ((cy + height / 2 - padTop) / scale).clamp(
        0.0,
        originalHeight.toDouble(),
      );

      candidates.add(
        _RawDetection(
          x1: x1,
          y1: y1,
          x2: x2,
          y2: y2,
          confidenceScore: maxScore,
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
      for (final result in kept) {
        final String className = entry.key < classNames.length
            ? classNames[entry.key]
            : 'class_${entry.key}';
        results.add(
          DetectionResult(
            className: className,
            confidenceScore: result.confidenceScore,
            boundingBox: BoundingBox(
              x1: result.x1,
              y1: result.y1,
              x2: result.x2,
              y2: result.y2,
            ),
          ),
        );
      }
    }
    results.sort(
      (result1, result2) =>
          result2.confidenceScore.compareTo(result1.confidenceScore),
    );
    return results;
  }

  List<_RawDetection> _nms(List<_RawDetection> detections) {
    detections.sort(
      (result1, result2) =>
          result2.confidenceScore.compareTo(result1.confidenceScore),
    );
    final suppressed = List.filled(detections.length, false);
    final kept = <_RawDetection>[];

    for (int i = 0; i < detections.length; i++) {
      if (suppressed[i]) continue;
      kept.add(detections[i]);
      for (int j = i + 1; j < detections.length; j++) {
        if (suppressed[j]) continue;
        if (_iou(detections[i], detections[j]) > iouThreshold)
          suppressed[j] = true;
      }
    }
    return kept;
  }

  double _iou(_RawDetection a, _RawDetection b) {
    final double ix1 = a.x1 > b.x1 ? a.x1 : b.x1;
    final double iy1 = a.y1 > b.y1 ? a.y1 : b.y1;
    final double ix2 = a.x2 < b.x2 ? a.x2 : b.x2;
    final double iy2 = a.y2 < b.y2 ? a.y2 : b.y2;
    final double iWidth = ix2 - ix1;
    final double iHeight = iy2 - iy1;
    if (iWidth <= 0 || iHeight <= 0) return 0.0;
    final double intersectionArea = iWidth * iHeight;
    final double unionArea =
        (a.x2 - a.x1) * (a.y2 - a.y1) +
        (b.x2 - b.x1) * (b.y2 - b.y1) -
        intersectionArea;
    return intersectionArea / unionArea;
  }
}

class _RawDetection {
  final double x1, y1, x2, y2, confidenceScore;
  final int classIndex;
  const _RawDetection({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.confidenceScore,
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
  final Uint8List src = input.rgbaBytes;

  final double scale =
      size / (originalWidth > originalHeight ? originalWidth : originalHeight);
  final int newWidth = (originalWidth * scale).round();
  final int newHeight = (originalHeight * scale).round();
  final int padLeft = (size - newWidth) ~/ 2;
  final int padTop = (size - newHeight) ~/ 2;

  final Float32List output = Float32List(3 * size * size);
  for (int i = 0; i < output.length; i++) output[i] = 0.5;

  for (int py = 0; py < newHeight; py++) {
    final double srcYf = py / scale;
    final int srcY0 = srcYf.floor().clamp(0, originalHeight - 1);
    final int srcY1 = (srcY0 + 1).clamp(0, originalHeight - 1);
    final double fy = srcYf - srcY0;

    for (int px = 0; px < newWidth; px++) {
      final double srcXf = px / scale;
      final int srcX0 = srcXf.floor().clamp(0, originalWidth - 1);
      final int srcX1 = (srcX0 + 1).clamp(0, originalWidth - 1);
      final double fx = srcXf - srcX0;

      final int i00 = (srcY0 * originalWidth + srcX0) * 4;
      final int i01 = (srcY0 * originalWidth + srcX1) * 4;
      final int i10 = (srcY1 * originalWidth + srcX0) * 4;
      final int i11 = (srcY1 * originalWidth + srcX1) * 4;

      for (int c = 0; c < 3; c++) {
        final double v =
            (src[i00 + c] * (1 - fx) + src[i01 + c] * fx) * (1 - fy) +
            (src[i10 + c] * (1 - fx) + src[i11 + c] * fx) * fy;

        final int destY = padTop + py;
        final int destX = padLeft + px;
        output[c * size * size + destY * size + destX] = v / 255.0;
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
