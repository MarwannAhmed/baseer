// lib/features/object_detection/application/on_device_object_detector.dart
//
// On-device inference via ONNX Runtime.
// Designed for YOLOv8 ONNX export (opset 12+).
//
// YOLOv8 ONNX output contract
// ────────────────────────────
// Input  name : "images"   shape [1, 3, inputSize, inputSize]  float32, values 0-1
// Output name : "output0"  shape [1, 4+numClasses, 8400]       float32
//   Row 0   = cx (centre-x in input-tensor pixels)
//   Row 1   = cy (centre-y in input-tensor pixels)
//   Row 2   = w  (width  in input-tensor pixels)
//   Row 3   = h  (height in input-tensor pixels)
//   Row 4…  = per-class confidence scores (already sigmoid'd by ONNX export)
//
// If your model uses a different layout (YOLOv5 / custom), see the NOTE in
// _postprocess() and adjust accordingly.

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

import '../domain/detection_result.dart';
import '../domain/object_detector.dart';

class OnDeviceObjectDetector implements ObjectDetector {
  /// Human-readable class names in the same order as the model's class indices.
  /// e.g. ['person', 'car', 'dog', ...]
  final List<String> classNames;

  /// Path to the .onnx file relative to the Flutter asset root.
  /// Default matches assets/ml/model.onnx in pubspec.yaml.
  final String modelAssetPath;

  /// Spatial resolution the model expects (default 640 for most YOLO models).
  final int inputSize;

  /// Detections with score below this are discarded before NMS.
  final double confidenceThreshold;

  /// IoU threshold used in non-maximum suppression.
  final double iouThreshold;

  OrtSession? _session;

  OnDeviceObjectDetector({
    required this.classNames,
    this.modelAssetPath = 'assets/ml/model.onnx',
    this.inputSize = 640,
    this.confidenceThreshold = 0.5,
    this.iouThreshold = 0.45,
  });

  // ── ObjectDetector interface ───────────────────────────────────────────────

  @override
  Future<void> init() async {
    OrtEnv.instance.init();
    // v1.4.x API: load asset bytes manually, then create session from buffer.
    final ByteData assetData = await rootBundle.load(modelAssetPath);
    final Uint8List modelBytes = assetData.buffer.asUint8List();
    final opts = OrtSessionOptions();
    _session = OrtSession.fromBuffer(modelBytes, opts);
    debugPrint('🟢 ONNX model loaded successfully');
  }

  @override
  Future<List<DetectionResult>> detect(img.Image image) async {
    if (_session == null) throw StateError('Call init() before detect().');

    // ── 1. Preprocess in a background isolate (keeps UI thread free) ──────────
    debugPrint('🔵 Starting preprocess'); // 🟢
    final preprocessed = await compute(
      _preprocessIsolate,
      _PreprocessInput(
        rgbaBytes: image.getBytes(order: img.ChannelOrder.rgba),
        originalWidth: image.width,
        originalHeight: image.height,
        inputSize: inputSize,
      ),
    );

debugPrint('🔵 Preprocess done'); // 🟢
    // ── 2. Build input tensor ─────────────────────────────────────────────────
    final inputTensor = OrtValueTensor.createTensorWithDataList(
      preprocessed.data,
      [1, 3, inputSize, inputSize],
    );

debugPrint('🔵 Tensor created'); // 🟢
    // ── 3. Run inference ──────────────────────────────────────────────────────
    // Use the session's reported input name so the code survives model renames.
    final inputs = {_session!.inputNames[0]: inputTensor};
    final runOptions = OrtRunOptions();
    final outputs = await _session!.runAsync(runOptions, inputs);
debugPrint('🔵 Inference done, outputs: ${outputs?.length}'); // 🟢
    inputTensor.release();
    runOptions.release();

    if (outputs == null || outputs.isEmpty || outputs[0] == null) {
  debugPrint('🔴 Outputs null or empty'); // 🟢
  return [];
}

    // ── 4. Postprocess ────────────────────────────────────────────────────────
    // outputs[0].value → List<List<List<double>>> shaped [1][4+nc][8400]
    final rawOutput = outputs[0]!.value as List;
    debugPrint('🔵 Starting postprocess'); // 🟢
    final results = _postprocess(
      rawOutput,
      image.width,
      image.height,
      preprocessed.scale,
      preprocessed.padLeft,
      preprocessed.padTop,
    );

debugPrint('🟢 Detection complete, found ${results.length} objects'); // 🟢
    for (final o in outputs) { o?.release(); }

    return results;
  }

  @override
  void dispose() {
    _session?.release();
    OrtEnv.instance.release();
    _session = null;
  }

  // ── Post-processing ────────────────────────────────────────────────────────

  List<DetectionResult> _postprocess(
    List rawOutput,
    int origW,
    int origH,
    double scale,
    int padLeft,
    int padTop,
  ) {
    // rawOutput[0] is a List of length (4 + numClasses).
    // Each element is a List of length 8400 (one value per anchor).
    //
    // NOTE: YOLOv5 / older YOLO uses a transposed layout:
    //   shape [1, 25200, 5+nc] instead of [1, 4+nc, 8400].
    //   If you get wrong results, swap the indexing below:
    //   instead of predictions[row][anchorIdx], use predictions[anchorIdx][row].

    final List predictions = rawOutput[0] as List; // [4+nc][8400]
    final int numRows    = predictions.length;
    final int numAnchors = (predictions[0] as List).length;
    final int numClasses = numRows - 4;

    final List<_RawDetection> candidates = [];

    for (int i = 0; i < numAnchors; i++) {
      // ── Find highest-confidence class for this anchor ──────────────────────
      double maxScore = 0.0;
      int bestClass   = 0;
      for (int c = 0; c < numClasses; c++) {
        final double score = (predictions[4 + c] as List)[i].toDouble();
        if (score > maxScore) {
          maxScore  = score;
          bestClass = c;
        }
      }

      if (maxScore < confidenceThreshold) continue;

      // ── Decode box from input-tensor pixel space → original-image pixels ───
      final double cx = (predictions[0] as List)[i].toDouble();
      final double cy = (predictions[1] as List)[i].toDouble();
      final double w  = (predictions[2] as List)[i].toDouble();
      final double h  = (predictions[3] as List)[i].toDouble();

      // Undo letterboxing: subtract padding, then undo scale
      final double x1 = ((cx - w / 2 - padLeft) / scale).clamp(0.0, origW.toDouble());
      final double y1 = ((cy - h / 2 - padTop)  / scale).clamp(0.0, origH.toDouble());
      final double x2 = ((cx + w / 2 - padLeft) / scale).clamp(0.0, origW.toDouble());
      final double y2 = ((cy + h / 2 - padTop)  / scale).clamp(0.0, origH.toDouble());

      candidates.add(_RawDetection(
        x1: x1, y1: y1, x2: x2, y2: y2,
        score: maxScore,
        classIndex: bestClass,
      ));
    }

    // ── NMS per class ──────────────────────────────────────────────────────────
    final Map<int, List<_RawDetection>> byClass = {};
    for (final d in candidates) {
      byClass.putIfAbsent(d.classIndex, () => []).add(d);
    }

    final List<DetectionResult> results = [];
    for (final entry in byClass.entries) {
      final kept = _nms(entry.value);
      for (final d in kept) {
        final String label = entry.key < classNames.length
            ? classNames[entry.key]
            : 'class_${entry.key}';
        results.add(DetectionResult(
          label: label,
          confidence: d.score,
          boundingBox: BoundingBox(
            x1: d.x1, y1: d.y1, x2: d.x2, y2: d.y2,
          ),
        ));
      }
    }

    // Sort by confidence descending so callers get the best detections first.
    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results;
  }

  // ── Non-Maximum Suppression ────────────────────────────────────────────────

  List<_RawDetection> _nms(List<_RawDetection> dets) {
    dets.sort((a, b) => b.score.compareTo(a.score));
    final suppressed = List.filled(dets.length, false);
    final kept       = <_RawDetection>[];

    for (int i = 0; i < dets.length; i++) {
      if (suppressed[i]) continue;
      kept.add(dets[i]);
      for (int j = i + 1; j < dets.length; j++) {
        if (suppressed[j]) continue;
        if (_iou(dets[i], dets[j]) > iouThreshold) suppressed[j] = true;
      }
    }
    return kept;
  }

  double _iou(_RawDetection a, _RawDetection b) {
    final double ix1 = a.x1 > b.x1 ? a.x1 : b.x1;
    final double iy1 = a.y1 > b.y1 ? a.y1 : b.y1;
    final double ix2 = a.x2 < b.x2 ? a.x2 : b.x2;
    final double iy2 = a.y2 < b.y2 ? a.y2 : b.y2;
    final double iw  = ix2 - ix1;
    final double ih  = iy2 - iy1;
    if (iw <= 0 || ih <= 0) return 0.0;
    final double inter = iw * ih;
    final double union = (a.x2-a.x1)*(a.y2-a.y1) + (b.x2-b.x1)*(b.y2-b.y1) - inter;
    return inter / union;
  }
}

// ── Internal helpers ───────────────────────────────────────────────────────────

class _RawDetection {
  final double x1, y1, x2, y2, score;
  final int classIndex;
  const _RawDetection({
    required this.x1, required this.y1,
    required this.x2, required this.y2,
    required this.score,
    required this.classIndex,
  });
}

// ── Preprocessing (runs in a background isolate) ───────────────────────────────
// Letterbox-resizes the image to inputSize×inputSize with a neutral-gray
// (0.5) border, then converts to CHW float32 in [0, 1].
//
// Returns scale and padding so the caller can un-letterbox bounding boxes.

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
  final Float32List data;  // CHW float32 ready for ONNX
  final double scale;      // uniform scale applied to the image
  final int padLeft;       // horizontal padding added (pixels)
  final int padTop;        // vertical   padding added (pixels)
  const _PreprocessOutput({
    required this.data,
    required this.scale,
    required this.padLeft,
    required this.padTop,
  });
}

_PreprocessOutput _preprocessIsolate(_PreprocessInput input) {
  final int size  = input.inputSize;
  final int origW = input.originalWidth;
  final int origH = input.originalHeight;
  final Uint8List src = input.rgbaBytes;

  // ── Letterbox geometry ────────────────────────────────────────────────────
  final double scale = size / (origW > origH ? origW : origH);
  final int newW   = (origW * scale).round();
  final int newH   = (origH * scale).round();
  final int padLeft = (size - newW) ~/ 2;
  final int padTop  = (size - newH) ~/ 2;

  // ── Allocate output tensor, pre-fill with 0.5 (gray letterbox border) ─────
  final Float32List output = Float32List(3 * size * size);
  for (int i = 0; i < output.length; i++) output[i] = 0.5;

  // ── Bilinear resize + normalize + CHW layout ──────────────────────────────
  for (int py = 0; py < newH; py++) {
    final double srcYf = py / scale;
    final int srcY0 = srcYf.floor().clamp(0, origH - 1);
    final int srcY1 = (srcY0 + 1).clamp(0, origH - 1);
    final double fy = srcYf - srcY0;

    for (int px = 0; px < newW; px++) {
      final double srcXf = px / scale;
      final int srcX0 = srcXf.floor().clamp(0, origW - 1);
      final int srcX1 = (srcX0 + 1).clamp(0, origW - 1);
      final double fx = srcXf - srcX0;

      // 4 neighbouring pixels (RGBA, 4 bytes each)
      final int i00 = (srcY0 * origW + srcX0) * 4;
      final int i01 = (srcY0 * origW + srcX1) * 4;
      final int i10 = (srcY1 * origW + srcX0) * 4;
      final int i11 = (srcY1 * origW + srcX1) * 4;

      // R=0, G=1, B=2  (skip A=3)
      for (int c = 0; c < 3; c++) {
        final double v =
            (src[i00 + c] * (1 - fx) + src[i01 + c] * fx) * (1 - fy) +
            (src[i10 + c] * (1 - fx) + src[i11 + c] * fx) * fy;

        final int destY = padTop  + py;
        final int destX = padLeft + px;
        // CHW index: channel * (H*W) + row * W + col
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