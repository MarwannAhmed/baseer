import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:baseer/features/color_recognition/application/color_detector_factory.dart';
import '../../helpers/test_fixtures.dart';

img.Image _solidColor(int r, int g, int b, {int size = 30}) {
  final image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ColorDetectorFactory (ruleBased)', () {
    late ColorDetectorFactory factory;

    setUp(() {
      factory = ColorDetectorFactory(mode: ColorDetectorMode.ruleBased);
    });

    test('detects red from solid red frame', () async {
      await factory.setFrame(_solidColor(220, 20, 20, size: 30));
      final result = factory.detect(0, 0, 30, 30);
      expect(result.colorEn, equals('red'));
      expect(result.colorAr, equals('أحمر'));
    });

    test('detects blue from solid blue frame', () async {
      await factory.setFrame(_solidColor(20, 20, 220, size: 30));
      final result = factory.detect(0, 0, 30, 30);
      expect(result.colorEn, equals('blue'));
    });

    group('detectColorsForObjects()', () {
      test('annotates non-person objects with color', () async {
        final image = _solidColor(220, 20, 20, size: 100);
        final objects = [
          makeDetectedObject(label: 'car', x1: 0, y1: 0, x2: 100, y2: 100),
        ];
        final result = await factory.detectColorsForObjects(image, objects);
        expect(result.first.colorEn, isNotEmpty);
      });

      test('skips color detection for person objects', () async {
        final image = _solidColor(220, 20, 20, size: 100);
        final objects = [
          makeDetectedObject(label: 'person', x1: 0, y1: 0, x2: 100, y2: 100),
        ];
        final result = await factory.detectColorsForObjects(image, objects);
        // person label → returned as-is, colorEn stays empty
        expect(result.first.colorEn, equals(''));
        expect(result.first.label, equals('person'));
      });

      test('handles mixed person and non-person objects', () async {
        final image = _solidColor(20, 20, 220, size: 100);
        final objects = [
          makeDetectedObject(label: 'person', x1: 0, y1: 0, x2: 50, y2: 50),
          makeDetectedObject(label: 'car', x1: 50, y1: 50, x2: 100, y2: 100),
        ];
        final result = await factory.detectColorsForObjects(image, objects);
        expect(result[0].colorEn, equals('')); // person skipped
        expect(result[1].colorEn, isNotEmpty); // car annotated
      });

      test('preserves all other fields when annotating', () async {
        final image = _solidColor(20, 180, 20, size: 100);
        final original = makeDetectedObject(
          label: 'dog', confidence: 0.77,
          x1: 0, y1: 0, x2: 100, y2: 100,
          distanceCm: 300,
        );
        final result = await factory.detectColorsForObjects(image, [original]);
        expect(result.first.label, equals('dog'));
        expect(result.first.confidence, equals(0.77));
        expect(result.first.distanceCm, equals(300));
      });
    });
  });
}
