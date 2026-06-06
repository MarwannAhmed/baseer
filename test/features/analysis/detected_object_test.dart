import 'package:flutter_test/flutter_test.dart';
import 'package:baseer/features/analysis/domain/detected_object.dart';

void main() {
  group('DetectedObject', () {
    group('fromJson()', () {
      final json = {
        'label': 'car',
        'confidence': 0.92,
        'bbox': {'x1': 10, 'y1': 20, 'x2': 110, 'y2': 220},
        'center': {'x': 60, 'y': 120},
        'size': {'width': 100, 'height': 200},
        'color_en': 'red',
        'color_ar': 'أحمر',
        'distance_cm': 350,
      };

      test('parses label', () {
        expect(DetectedObject.fromJson(json).label, equals('car'));
      });

      test('parses confidence as double', () {
        expect(DetectedObject.fromJson(json).confidence, closeTo(0.92, 0.001));
      });

      test('parses bbox values', () {
        final obj = DetectedObject.fromJson(json);
        expect(obj.bbox['x1'], equals(10));
        expect(obj.bbox['y1'], equals(20));
        expect(obj.bbox['x2'], equals(110));
        expect(obj.bbox['y2'], equals(220));
      });

      test('parses center values', () {
        final obj = DetectedObject.fromJson(json);
        expect(obj.center['x'], equals(60));
        expect(obj.center['y'], equals(120));
      });

      test('parses size values', () {
        final obj = DetectedObject.fromJson(json);
        expect(obj.size['width'], equals(100));
        expect(obj.size['height'], equals(200));
      });

      test('parses colorEn and colorAr', () {
        final obj = DetectedObject.fromJson(json);
        expect(obj.colorEn, equals('red'));
        expect(obj.colorAr, equals('أحمر'));
      });

      test('parses distanceCm', () {
        expect(DetectedObject.fromJson(json).distanceCm, equals(350));
      });

      test('colorEn defaults to empty string when missing', () {
        final obj = DetectedObject.fromJson({...json}..remove('color_en'));
        expect(obj.colorEn, equals(''));
      });

      test('colorAr defaults to empty string when missing', () {
        final obj = DetectedObject.fromJson({...json}..remove('color_ar'));
        expect(obj.colorAr, equals(''));
      });

      test('distanceCm defaults to 0 when missing', () {
        final obj = DetectedObject.fromJson({...json}..remove('distance_cm'));
        expect(obj.distanceCm, equals(0));
      });

      test('bbox defaults to empty map when null', () {
        final obj = DetectedObject.fromJson({...json, 'bbox': null});
        expect(obj.bbox, isEmpty);
      });
    });

    group('fromDetectionResult()', () {
      final obj = DetectedObject.fromDetectionResult(
        label: 'person',
        confidence: 0.88,
        x1: 10, y1: 20, x2: 90, y2: 180,
      );

      test('center x is (x1+x2)/2 rounded', () {
        expect(obj.center['x'], equals(50)); // (10+90)/2 = 50
      });

      test('center y is (y1+y2)/2 rounded', () {
        expect(obj.center['y'], equals(100)); // (20+180)/2 = 100
      });

      test('size width is x2-x1', () {
        expect(obj.size['width'], equals(80)); // 90-10
      });

      test('size height is y2-y1', () {
        expect(obj.size['height'], equals(160)); // 180-20
      });

      test('colorEn defaults to empty string', () {
        expect(obj.colorEn, equals(''));
      });

      test('colorAr defaults to empty string', () {
        expect(obj.colorAr, equals(''));
      });

      test('distanceCm defaults to 0', () {
        expect(obj.distanceCm, equals(0));
      });

      test('odd pixel coordinates round correctly', () {
        final o = DetectedObject.fromDetectionResult(
          label: 'cat', confidence: 0.5,
          x1: 11, y1: 21, x2: 90, y2: 181,
        );
        expect(o.center['x'], equals(51)); // (11+90)/2 = 50.5 → 51
        expect(o.center['y'], equals(101)); // (21+181)/2 = 101
      });
    });

    group('copyWithDistance()', () {
      final original = DetectedObject.fromDetectionResult(
        label: 'dog', confidence: 0.75,
        x1: 0, y1: 0, x2: 50, y2: 50,
      );

      test('preserves all fields except distanceCm', () {
        final updated = original.copyWithDistance(distanceCm: 500);
        expect(updated.label, equals(original.label));
        expect(updated.confidence, equals(original.confidence));
        expect(updated.bbox, equals(original.bbox));
        expect(updated.center, equals(original.center));
        expect(updated.size, equals(original.size));
        expect(updated.colorEn, equals(original.colorEn));
        expect(updated.colorAr, equals(original.colorAr));
      });

      test('updates distanceCm to the new value', () {
        final updated = original.copyWithDistance(distanceCm: 500);
        expect(updated.distanceCm, equals(500));
      });
    });
  });
}
