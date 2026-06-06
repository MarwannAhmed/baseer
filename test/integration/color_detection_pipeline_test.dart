import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:baseer/features/color_recognition/application/color_detector_factory.dart';
import '../helpers/test_fixtures.dart';

img.Image _solidColor(int r, int g, int b, {int size = 50}) {
  final image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Color detection pipeline (rule-based)', () {
    late ColorDetectorFactory factory;

    setUp(() {
      factory = ColorDetectorFactory(mode: ColorDetectorMode.ruleBased);
    });

    test('red image → colorEn=red, colorAr=أحمر', () async {
      await factory.setFrame(_solidColor(220, 20, 20));
      final result = factory.detect(0, 0, 50, 50);
      expect(result.colorEn, equals('red'));
      expect(result.colorAr, equals('أحمر'));
    });

    test('green image → colorEn=green, colorAr=أخضر', () async {
      await factory.setFrame(_solidColor(20, 180, 20));
      final result = factory.detect(0, 0, 50, 50);
      expect(result.colorEn, equals('green'));
      expect(result.colorAr, equals('أخضر'));
    });

    test('blue image → colorEn=blue', () async {
      await factory.setFrame(_solidColor(20, 20, 220));
      final result = factory.detect(0, 0, 50, 50);
      expect(result.colorEn, equals('blue'));
    });

    test('detectColorsForObjects: person label skipped, car annotated', () async {
      final image = _solidColor(220, 20, 20, size: 100);
      final objects = [
        makeDetectedObject(label: 'person', x1: 0, y1: 0, x2: 50, y2: 50),
        makeDetectedObject(label: 'car', x1: 50, y1: 50, x2: 100, y2: 100),
      ];
      final result = await factory.detectColorsForObjects(image, objects);
      expect(result[0].label, equals('person'));
      expect(result[0].colorEn, equals('')); // person skipped
      expect(result[1].label, equals('car'));
      expect(result[1].colorEn, isNotEmpty); // car annotated
    });

    test('detectColorsForObjects: all non-person objects get color', () async {
      final image = _solidColor(20, 20, 220, size: 100);
      final objects = [
        makeDetectedObject(label: 'chair', x1: 0, y1: 0, x2: 100, y2: 100),
        makeDetectedObject(label: 'laptop', x1: 0, y1: 0, x2: 100, y2: 100),
      ];
      final result = await factory.detectColorsForObjects(image, objects);
      for (final obj in result) {
        expect(obj.colorEn, isNotEmpty,
            reason: '${obj.label} should have color annotated');
      }
    });

    test('detectColorsForObjects preserves label and confidence', () async {
      final image = _solidColor(220, 20, 20, size: 100);
      final original = makeDetectedObject(
        label: 'dog',
        confidence: 0.77,
        x1: 0, y1: 0, x2: 100, y2: 100,
      );
      final result = await factory.detectColorsForObjects(image, [original]);
      expect(result.first.label, equals('dog'));
      expect(result.first.confidence, equals(0.77));
    });
  });
}
