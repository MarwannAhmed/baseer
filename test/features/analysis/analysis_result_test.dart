import 'package:flutter_test/flutter_test.dart';
import 'package:baseer/features/analysis/domain/analysis_result.dart';

void main() {
  group('AnalysisResult', () {
    group('fromJson()', () {
      test('parses description correctly', () {
        final result = AnalysisResult.fromJson({
          'description': 'a red car',
          'objects': [],
        });
        expect(result.description, equals('a red car'));
      });

      test('parses non-empty objects list', () {
        final result = AnalysisResult.fromJson({
          'description': 'scene',
          'objects': [
            {
              'label': 'car',
              'confidence': 0.9,
              'bbox': {'x1': 10, 'y1': 10, 'x2': 100, 'y2': 100},
              'center': {'x': 55, 'y': 55},
              'size': {'width': 90, 'height': 90},
            }
          ],
        });
        expect(result.objects.length, equals(1));
        expect(result.objects.first.label, equals('car'));
      });

      test('defaults objects to empty list when key is missing', () {
        final result = AnalysisResult.fromJson({'description': 'test'});
        expect(result.objects, isEmpty);
      });

      test('defaults description to empty string when key is missing', () {
        final result = AnalysisResult.fromJson({'objects': []});
        expect(result.description, equals(''));
      });

      test('defaults description to empty string when value is null', () {
        final result = AnalysisResult.fromJson({'description': null, 'objects': []});
        expect(result.description, equals(''));
      });
    });

    test('toString() returns description', () {
      const result = AnalysisResult(description: 'hello', objects: []);
      expect(result.toString(), equals('hello'));
    });
  });
}
