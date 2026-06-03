import 'package:image/image.dart' as img;

import 'package:baseer/features/color_recognition/application/color_detector.dart';      // ColorDetector, ColorResult
import 'package:baseer/features/color_recognition/application/color_detector_svm.dart';  // ColorDetectorSvm, SvmColorResult, SvmColorClassifier

// ─────────────────────────────────────────────────────────────────────────────
// ColorDetectorMode
// ─────────────────────────────────────────────────────────────────────────────

enum ColorDetectorMode {
  /// Original rule-based pipeline (no dependencies, always available).
  ruleBased,

  /// SVM + ONNX pipeline (requires assets/ml/ and onnxruntime package).
  /// Falls back to rule-based prototype classifier if the ONNX session is
  /// not yet loaded.
  svm,
}

// ─────────────────────────────────────────────────────────────────────────────
// ColorDetectorFactory
// ─────────────────────────────────────────────────────────────────────────────
//
// Usage — pick a mode once at startup and use the factory throughout:
//
//   // main.dart
//   ColorDetectorFactory.mode = ColorDetectorMode.svm;
//   runApp(const BaseerApp());
//
//   // wherever you detect colors:
//   final factory = ColorDetectorFactory();
//   final results = await factory.detectColorsForObjects(frame, objects);
//
// Switching modes at runtime is supported — just change ColorDetectorFactory.mode.

class ColorDetectorFactory {
  /// The active backend. Change this before (or after) app start.
  /// Defaults to [ColorDetectorMode.ruleBased] so the app works out of the
  /// box without any ONNX assets.
  static ColorDetectorMode mode = ColorDetectorMode.ruleBased;

  final ColorDetector    _ruleBased = ColorDetector();
  final ColorDetectorSvm _svm       = ColorDetectorSvm();

  // ── Unified API ─────────────────────────────────────────────────────────────

  /// Pre-process a camera frame for the active backend.
  Future<void> setFrame(img.Image frame) {
    return switch (mode) {
      ColorDetectorMode.ruleBased => _ruleBased.setFrame(frame),
      ColorDetectorMode.svm       => _svm.setFrame(frame),
    };
  }

  ColorDetectorFactory();
  /// Detect the dominant color in a bounding box.
  /// Returns a [UnifiedColorResult] regardless of which backend is active.
  UnifiedColorResult detect(int x1, int y1, int x2, int y2) {
    return switch (mode) {
      ColorDetectorMode.ruleBased => _ruleBased.detect(x1, y1, x2, y2).toUnified(),
      ColorDetectorMode.svm       => _svm.detect(x1, y1, x2, y2).toUnified(),
    };
  }

  /// Convenience method: enriches each object map with 'color_en' / 'color_ar'.
  Future<List<Map<String, dynamic>>> detectColorsForObjects(
    img.Image frame,
    List<Map<String, dynamic>> objects,
  ) async {
    await setFrame(frame);
    return objects.map((obj) {
      final bbox = obj['bbox'] as Map<String, dynamic>;
      final r = detect(
        (bbox['x1'] as num).toInt(), (bbox['y1'] as num).toInt(),
        (bbox['x2'] as num).toInt(), (bbox['y2'] as num).toInt(),
      );
      return {...obj, 'color_en': r.colorEn, 'color_ar': r.colorAr};
    }).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UnifiedColorResult — common return type so callers don't import both files
// ─────────────────────────────────────────────────────────────────────────────

class UnifiedColorResult {
  final String colorEn;
  final String colorAr;
  const UnifiedColorResult({required this.colorEn, required this.colorAr});

  @override
  String toString() => '$colorEn / $colorAr';
}

// ── Extension helpers ─────────────────────────────────────────────────────────

extension ColorResultX on ColorResult {
  UnifiedColorResult toUnified() =>
      UnifiedColorResult(colorEn: colorEn, colorAr: colorAr);
}

extension SvmColorResultX on SvmColorResult {
  UnifiedColorResult toUnified() =>
      UnifiedColorResult(colorEn: colorEn, colorAr: colorAr);
}