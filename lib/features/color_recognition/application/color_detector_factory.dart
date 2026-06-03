import 'package:image/image.dart' as img;

import 'package:baseer/features/analysis/domain/detected_object.dart';
import 'package:baseer/features/color_recognition/application/color_detector.dart';
import 'package:baseer/features/color_recognition/application/color_detector_svm.dart';

enum ColorDetectorMode {
  ruleBased, // original rule-based, no deps, always works out of the box
  svm,       // onnx svm -- needs assets/ml/ and the onnxruntime package
}

class ColorDetectorFactory {
  // change before (or after) app start. switching at runtime is fine
  // defaults to ruleBased so the app works w/o any onnx assets
  static ColorDetectorMode mode = ColorDetectorMode.ruleBased;

  // both held so we dont reinit on every mode switch
  final ColorDetector    _ruleBased = ColorDetector();
  final ColorDetectorSvm _svm       = ColorDetectorSvm();

  ColorDetectorFactory();

  Future<void> setFrame(img.Image frame) {
    return switch (mode) {
      ColorDetectorMode.ruleBased => _ruleBased.setFrame(frame),
      ColorDetectorMode.svm       => _svm.setFrame(frame),
    };
  }

  UnifiedColorResult detect(int x1, int y1, int x2, int y2) {
    return switch (mode) {
      ColorDetectorMode.ruleBased => _ruleBased.detect(x1, y1, x2, y2).toUnified(),
      ColorDetectorMode.svm       => _svm.detect(x1, y1, x2, y2).toUnified(),
    };
  }

  Future<void> detectColorsForObjects(
    img.Image frame,
    List<DetectedObject> objects,
  ) async {
    await setFrame(frame);
    for (final obj in objects) {
      final r = detect(
        obj.bbox['x1'] ?? 0, obj.bbox['y1'] ?? 0,
        obj.bbox['x2'] ?? 0, obj.bbox['y2'] ?? 0,
      );
      obj.colorEn = r.colorEn;
      obj.colorAr = r.colorAr;
    }
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
