import 'package:image/image.dart' as img;
import 'package:baseer/features/analysis/domain/detected_object.dart';
import 'package:baseer/features/color_recognition/application/color_detector.dart';

enum ColorDetectorMode {
  ruleBased, // original rule-based
  svm,       // onnx svm -- needs assets/ml/ and the onnxruntime package
  backend,   // remote HTTP backend at BASE_URI
}

class ColorDetectorFactory {
  final ColorDetectorMode mode;
  final ColorDetector    _ruleBased = ColorDetector();

  ColorDetectorFactory({this.mode = ColorDetectorMode.ruleBased, String? baseUrl});

  Future<void> setFrame(img.Image frame) async {
    return _ruleBased.setFrame(frame);
  }

  UnifiedColorResult detect(int x1, int y1, int x2, int y2) {
    return _ruleBased.detect(x1, y1, x2, y2).toUnified();
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
