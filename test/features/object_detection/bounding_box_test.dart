import 'package:flutter_test/flutter_test.dart';
import 'package:baseer/features/object_detection/domain/detection_result.dart';

void main() {
  group('BoundingBox', () {
    const box = BoundingBox(x1: 10, y1: 20, x2: 110, y2: 220);

    test('width equals x2 - x1', () {
      expect(box.width, equals(100.0));
    });

    test('height equals y2 - y1', () {
      expect(box.height, equals(200.0));
    });

    test('centerX equals (x1 + x2) / 2', () {
      expect(box.centerX, equals(60.0));
    });

    test('centerY equals (y1 + y2) / 2', () {
      expect(box.centerY, equals(120.0));
    });

    test('zero-width box has width 0', () {
      const zeroBox = BoundingBox(x1: 50, y1: 0, x2: 50, y2: 100);
      expect(zeroBox.width, equals(0.0));
    });

    test('zero-width box centerX equals x1', () {
      const zeroBox = BoundingBox(x1: 50, y1: 0, x2: 50, y2: 100);
      expect(zeroBox.centerX, equals(50.0));
    });

    test('fractional coordinates produce correct center', () {
      const fBox = BoundingBox(x1: 0.5, y1: 0.5, x2: 1.5, y2: 1.5);
      expect(fBox.centerX, equals(1.0));
      expect(fBox.centerY, equals(1.0));
    });
  });
}
