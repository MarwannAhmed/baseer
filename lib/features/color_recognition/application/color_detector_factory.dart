import 'package:image/image.dart' as img;

import 'package:baseer/features/analysis/domain/detected_object.dart';
import 'package:baseer/features/color_recognition/application/color_detector.dart';
import 'package:baseer/features/color_recognition/application/color_detector_svm.dart';
import 'package:baseer/features/color_recognition/application/remote_color_detector.dart';

enum ColorDetectorMode {
  ruleBased, // original rule-based, no deps, always works out of the box
  svm,       // onnx svm -- needs assets/ml/ and the onnxruntime package
  backend,   // remote HTTP backend at BASE_URI
}

class ColorDetectorFactory {
  final ColorDetectorMode mode;

  // both held so we dont reinit on every mode switch
  final ColorDetector    _ruleBased = ColorDetector();
  final ColorDetectorSvm _svm       = ColorDetectorSvm();
  RemoteColorDetector?   _remote;

  UnifiedColorResult? _cachedRemoteResult;

  ColorDetectorFactory({this.mode = ColorDetectorMode.ruleBased, String? baseUrl}) {
    if (mode == ColorDetectorMode.backend) {
      _remote = RemoteColorDetector(baseUrl: baseUrl ?? 'http://127.0.0.1:8000');
    }
  }

  Future<void> setFrame(img.Image frame) async {
    switch (mode) {
      case ColorDetectorMode.ruleBased:
        return _ruleBased.setFrame(frame);
      case ColorDetectorMode.svm:
        return _svm.setFrame(frame);
      case ColorDetectorMode.backend:
        _cachedRemoteResult = await _remote!.detect(frame);
    }
  }

  UnifiedColorResult detect(int x1, int y1, int x2, int y2) {
    return switch (mode) {
      ColorDetectorMode.ruleBased => _ruleBased.detect(x1, y1, x2, y2).toUnified(),
      ColorDetectorMode.svm       => _svm.detect(x1, y1, x2, y2).toUnified(),
      ColorDetectorMode.backend   => _cachedRemoteResult ??
          const UnifiedColorResult(colorEn: 'unknown', colorAr: 'غير معروف'),
    };
  }

  Future<List<DetectedObject>> detectColorsForObjects(
    img.Image frame,
    List<DetectedObject> objects,
  ) async {
    await setFrame(frame);
    return objects.map((obj) {
      if (obj.label == 'person') {
        return obj;
      }
      final r = detect(
        obj.bbox['x1'] ?? 0, obj.bbox['y1'] ?? 0,
        obj.bbox['x2'] ?? 0, obj.bbox['y2'] ?? 0,
      );
      return DetectedObject(
        label:      obj.label,
        confidence: obj.confidence,
        bbox:       obj.bbox,
        center:     obj.center,
        size:       obj.size,
        colorEn:    r.colorEn,
        colorAr:    r.colorAr,
        distanceCm: obj.distanceCm,
      );
    }).toList();
  }
}

// common return type so callers dont need to import both detector files
class UnifiedColorResult {
  final String colorEn;
  final String colorAr;
  const UnifiedColorResult({required this.colorEn, required this.colorAr});

  @override
  String toString() => '$colorEn / $colorAr';
}

extension ColorResultX on ColorResult {
  UnifiedColorResult toUnified() =>
      UnifiedColorResult(colorEn: colorEn, colorAr: colorAr);
}

extension SvmColorResultX on SvmColorResult {
  UnifiedColorResult toUnified() =>
      UnifiedColorResult(colorEn: colorEn, colorAr: colorAr);
}
