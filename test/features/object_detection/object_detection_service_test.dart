import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:baseer/features/object_detection/application/object_detection_service.dart';
import 'package:baseer/features/object_detection/domain/detection_result.dart';
import '../../helpers/fakes.dart';

void main() {
  group('ObjectDetectionService', () {
    late FakeObjectDetector fakeDetector;
    late ObjectDetectionService service;

    setUp(() {
      fakeDetector = FakeObjectDetector();
      service = ObjectDetectionService.fromDetector(fakeDetector);
    });

    test('init() delegates to the underlying detector', () async {
      expect(fakeDetector.initCalled, isFalse);
      await service.init();
      expect(fakeDetector.initCalled, isTrue);
    });

    test('dispose() delegates to the underlying detector', () {
      expect(fakeDetector.disposeCalled, isFalse);
      service.dispose();
      expect(fakeDetector.disposeCalled, isTrue);
    });

    group('detectObjects()', () {
      final image = img.Image(width: 640, height: 480);

      test('returns empty list when detector returns empty list', () async {
        fakeDetector.results = [];
        final result = await service.detectObjects(image);
        expect(result, isEmpty);
      });

      test('maps DetectionResult to DetectedObject with correct label', () async {
        fakeDetector.results = [
          DetectionResult(
            label: 'person',
            confidence: 0.95,
            boundingBox: const BoundingBox(x1: 10.4, y1: 20.6, x2: 100.5, y2: 200.4),
          ),
        ];
        final result = await service.detectObjects(image);
        expect(result.length, equals(1));
        expect(result.first.label, equals('person'));
      });

      test('rounds bounding box coordinates', () async {
        fakeDetector.results = [
          DetectionResult(
            label: 'car',
            confidence: 0.8,
            boundingBox: const BoundingBox(x1: 10.4, y1: 20.6, x2: 100.5, y2: 200.4),
          ),
        ];
        final result = await service.detectObjects(image);
        expect(result.first.bbox['x1'], equals(10));
        expect(result.first.bbox['y1'], equals(21));
        expect(result.first.bbox['x2'], equals(101));
        expect(result.first.bbox['y2'], equals(200));
      });

      test('maps confidence correctly', () async {
        fakeDetector.results = [
          DetectionResult(
            label: 'dog',
            confidence: 0.77,
            boundingBox: const BoundingBox(x1: 0, y1: 0, x2: 50, y2: 50),
          ),
        ];
        final result = await service.detectObjects(image);
        expect(result.first.confidence, closeTo(0.77, 0.001));
      });

      test('maps multiple results', () async {
        fakeDetector.results = [
          DetectionResult(
            label: 'cat',
            confidence: 0.9,
            boundingBox: const BoundingBox(x1: 0, y1: 0, x2: 30, y2: 30),
          ),
          DetectionResult(
            label: 'dog',
            confidence: 0.85,
            boundingBox: const BoundingBox(x1: 50, y1: 50, x2: 100, y2: 100),
          ),
        ];
        final result = await service.detectObjects(image);
        expect(result.length, equals(2));
        expect(result[0].label, equals('cat'));
        expect(result[1].label, equals('dog'));
      });
    });
  });
}
