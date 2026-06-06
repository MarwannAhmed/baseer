import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:baseer/features/object_detection/application/object_detection_service.dart';
import 'package:baseer/features/object_detection/application/detection_formatter.dart';
import 'package:baseer/features/object_detection/domain/detection_result.dart';
import '../helpers/fakes.dart';

void main() {
  group('Object detection pipeline', () {
    late FakeObjectDetector fakeDetector;
    late ObjectDetectionService service;
    final image = img.Image(width: 640, height: 480);

    setUp(() {
      fakeDetector = FakeObjectDetector();
      service = ObjectDetectionService.fromDetector(fakeDetector);
    });

    test('car detection → Arabic sentence contains سيارة', () async {
      fakeDetector.results = [
        DetectionResult(
          label: 'car',
          confidence: 0.9,
          boundingBox: const BoundingBox(x1: 10, y1: 10, x2: 110, y2: 110),
        ),
      ];
      final objects = await service.detectObjects(image);
      final sentence = DetectionFormatter.toSentenceFromObjects(objects);
      expect(sentence, contains('سيارة'));
    });

    test('person detection → Arabic sentence contains شخص', () async {
      fakeDetector.results = [
        DetectionResult(
          label: 'person',
          confidence: 0.95,
          boundingBox: const BoundingBox(x1: 0, y1: 0, x2: 80, y2: 200),
        ),
      ];
      final objects = await service.detectObjects(image);
      final sentence = DetectionFormatter.toSentenceFromObjects(objects);
      expect(sentence, contains('شخص'));
    });

    test('car detection → English sentence contains car', () async {
      fakeDetector.results = [
        DetectionResult(
          label: 'car',
          confidence: 0.9,
          boundingBox: const BoundingBox(x1: 10, y1: 10, x2: 110, y2: 110),
        ),
      ];
      final objects = await service.detectObjects(image);
      final sentence = DetectionFormatter.toSentenceFromObjects(objects, isArabic: false);
      expect(sentence, contains('car'));
    });

    test('multiple objects → sentence lists all labels', () async {
      fakeDetector.results = [
        DetectionResult(
          label: 'car',
          confidence: 0.9,
          boundingBox: const BoundingBox(x1: 0, y1: 0, x2: 100, y2: 100),
        ),
        DetectionResult(
          label: 'dog',
          confidence: 0.8,
          boundingBox: const BoundingBox(x1: 200, y1: 200, x2: 300, y2: 300),
        ),
      ];
      final objects = await service.detectObjects(image);
      final sentence = DetectionFormatter.toSentenceFromObjects(objects);
      expect(sentence, contains('سيارة'));
      expect(sentence, contains('كلب'));
    });

    test('empty detection → returns not-found sentence', () async {
      fakeDetector.results = [];
      final objects = await service.detectObjects(image);
      final sentence = DetectionFormatter.toSentenceFromObjects(objects);
      expect(sentence, equals('لا يوجد أي شيء في المشهد.'));
    });
  });
}
