import 'package:flutter_test/flutter_test.dart';
import 'package:baseer/features/object_detection/application/detection_formatter.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  group('DetectionFormatter.toSentenceFromObjects', () {
    group('English mode', () {
      test('empty list returns Nothing detected.', () {
        expect(
          DetectionFormatter.toSentenceFromObjects([], isArabic: false),
          equals('Nothing detected.'),
        );
      });

      test('single object no extras returns I see a <label>.', () {
        final objs = [makeDetectedObject(label: 'car')];
        expect(
          DetectionFormatter.toSentenceFromObjects(objs, isArabic: false),
          equals('I see a car.'),
        );
      });

      test('single object with color includes color before label', () {
        final objs = [makeDetectedObject(label: 'car', colorEn: 'red')];
        expect(
          DetectionFormatter.toSentenceFromObjects(objs, isArabic: false),
          equals('I see a red car.'),
        );
      });

      test('single object with distance appends distance', () {
        final objs = [makeDetectedObject(label: 'car', distanceCm: 200)];
        expect(
          DetectionFormatter.toSentenceFromObjects(objs, isArabic: false),
          equals('I see a car at distance 200 cm.'),
        );
      });

      test('single object with color and distance combines both', () {
        final objs = [makeDetectedObject(label: 'car', colorEn: 'red', distanceCm: 200)];
        expect(
          DetectionFormatter.toSentenceFromObjects(objs, isArabic: false),
          equals('I see a red car at distance 200 cm.'),
        );
      });

      test('two objects uses , and conjunction', () {
        final objs = [
          makeDetectedObject(label: 'car'),
          makeDetectedObject(label: 'dog'),
        ];
        expect(
          DetectionFormatter.toSentenceFromObjects(objs, isArabic: false),
          equals('I see a car, and a dog.'),
        );
      });

      test('three objects uses commas and final and', () {
        final objs = [
          makeDetectedObject(label: 'car'),
          makeDetectedObject(label: 'dog'),
          makeDetectedObject(label: 'cat'),
        ];
        expect(
          DetectionFormatter.toSentenceFromObjects(objs, isArabic: false),
          equals('I see a car, a dog, and a cat.'),
        );
      });

      test('six objects with default maxObjects=5 shows only first 5', () {
        final objs = List.generate(6, (i) => makeDetectedObject(label: 'car'));
        final result = DetectionFormatter.toSentenceFromObjects(objs, isArabic: false);
        // Should not contain a 6th "car"
        final count = 'a car'.allMatches(result).length;
        expect(count, equals(5));
      });

      test('distanceCm=0 produces no distance suffix', () {
        final objs = [makeDetectedObject(label: 'car', distanceCm: 0)];
        final result = DetectionFormatter.toSentenceFromObjects(objs, isArabic: false);
        expect(result, isNot(contains('distance')));
      });
    });

    group('Arabic mode (default)', () {
      test('empty list returns Arabic not-found sentence', () {
        expect(
          DetectionFormatter.toSentenceFromObjects([]),
          equals('لا يوجد أي شيء في المشهد.'),
        );
      });

      test("'car' label maps to 'سيارة'", () {
        final objs = [makeDetectedObject(label: 'car')];
        expect(
          DetectionFormatter.toSentenceFromObjects(objs),
          contains('سيارة'),
        );
      });

      test("'person' label maps to 'شخص'", () {
        final objs = [makeDetectedObject(label: 'person')];
        expect(
          DetectionFormatter.toSentenceFromObjects(objs),
          contains('شخص'),
        );
      });

      test('unknown label uses raw string as fallback', () {
        final objs = [makeDetectedObject(label: 'unknown_xyz')];
        expect(
          DetectionFormatter.toSentenceFromObjects(objs),
          contains('unknown_xyz'),
        );
      });

      test('single object with Arabic color includes it', () {
        final objs = [makeDetectedObject(label: 'car', colorAr: 'أحمر')];
        final result = DetectionFormatter.toSentenceFromObjects(objs);
        expect(result, contains('أحمر'));
      });

      test('single object with distance uses Arabic format', () {
        final objs = [makeDetectedObject(label: 'car', distanceCm: 150)];
        final result = DetectionFormatter.toSentenceFromObjects(objs);
        expect(result, contains('150'));
        expect(result, contains('سم'));
      });

      test('single object returns أرى sentence', () {
        final objs = [makeDetectedObject(label: 'dog')];
        final result = DetectionFormatter.toSentenceFromObjects(objs);
        expect(result, startsWith('أرى'));
      });

      test('two objects uses Arabic و conjunction', () {
        final objs = [
          makeDetectedObject(label: 'car'),
          makeDetectedObject(label: 'dog'),
        ];
        final result = DetectionFormatter.toSentenceFromObjects(objs);
        expect(result, contains('و'));
      });

      test('custom maxObjects limits output', () {
        final objs = List.generate(4, (i) => makeDetectedObject(label: 'car'));
        final result = DetectionFormatter.toSentenceFromObjects(objs, maxObjects: 2);
        final count = 'سيارة'.allMatches(result).length;
        expect(count, equals(2));
      });
    });
  });
}
