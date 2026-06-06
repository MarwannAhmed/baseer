import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:baseer/features/color_recognition/application/color_detector.dart';

img.Image _solidColor(int r, int g, int b, {int size = 30}) {
  final image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ColorDetector', () {
    late ColorDetector detector;

    setUp(() {
      detector = ColorDetector();
    });

    test('throws StateError when detect() called before setFrame()', () {
      expect(() => detector.detect(0, 0, 30, 30), throwsA(isA<StateError>()));
    });

    test('returns gray fallback when bbox area < minBboxArea (400)', () async {
      await detector.setFrame(_solidColor(255, 0, 0, size: 30));
      // 10×10 = 100 < 400
      final result = detector.detect(0, 0, 10, 10);
      expect(result.colorEn, equals('gray'));
    });

    test('returns gray fallback when x2 <= x1', () async {
      await detector.setFrame(_solidColor(255, 0, 0, size: 30));
      final result = detector.detect(15, 0, 15, 30);
      expect(result.colorEn, equals('gray'));
    });

    test('detects red', () async {
      await detector.setFrame(_solidColor(220, 20, 20, size: 30));
      final result = detector.detect(0, 0, 30, 30);
      expect(result.colorEn, equals('red'));
      expect(result.colorAr, equals('أحمر'));
    });

    test('detects green', () async {
      await detector.setFrame(_solidColor(20, 180, 20, size: 30));
      final result = detector.detect(0, 0, 30, 30);
      expect(result.colorEn, equals('green'));
      expect(result.colorAr, equals('أخضر'));
    });

    test('detects blue', () async {
      await detector.setFrame(_solidColor(20, 20, 220, size: 30));
      final result = detector.detect(0, 0, 30, 30);
      expect(result.colorEn, equals('blue'));
      expect(result.colorAr, equals('أزرق'));
    });

    test('detects white', () async {
      await detector.setFrame(_solidColor(255, 255, 255, size: 30));
      final result = detector.detect(0, 0, 30, 30);
      expect(result.colorEn, equals('white'));
      expect(result.colorAr, equals('أبيض'));
    });

    test('detects black', () async {
      await detector.setFrame(_solidColor(0, 0, 0, size: 30));
      final result = detector.detect(0, 0, 30, 30);
      expect(result.colorEn, equals('black'));
      expect(result.colorAr, equals('أسود'));
    });

    test('detects gray', () async {
      await detector.setFrame(_solidColor(128, 128, 128, size: 30));
      final result = detector.detect(0, 0, 30, 30);
      expect(result.colorEn, equals('gray'));
      expect(result.colorAr, equals('رمادي'));
    });

    test('detects yellow', () async {
      await detector.setFrame(_solidColor(230, 230, 10, size: 30));
      final result = detector.detect(0, 0, 30, 30);
      expect(result.colorEn, equals('yellow'));
    });

    test('setFrame can be called multiple times', () async {
      await detector.setFrame(_solidColor(255, 0, 0, size: 30));
      expect(detector.detect(0, 0, 30, 30).colorEn, equals('red'));
      await detector.setFrame(_solidColor(20, 20, 220, size: 30));
      expect(detector.detect(0, 0, 30, 30).colorEn, equals('blue'));
    });
  });
}
