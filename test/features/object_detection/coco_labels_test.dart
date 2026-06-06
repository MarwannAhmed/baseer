import 'package:flutter_test/flutter_test.dart';
import 'package:baseer/features/object_detection/domain/coco_labels.dart';

void main() {
  group('cocoClassNames', () {
    test('has exactly 80 labels', () {
      expect(cocoClassNames.length, equals(80));
    });

    test('first label is person', () {
      expect(cocoClassNames.first, equals('person'));
    });

    test('last label is toothbrush', () {
      expect(cocoClassNames.last, equals('toothbrush'));
    });

    test('has no duplicates', () {
      expect(cocoClassNames.toSet().length, equals(80));
    });

    test('all entries are non-empty strings', () {
      for (final label in cocoClassNames) {
        expect(label, isNotEmpty);
      }
    });

    test('contains expected common labels', () {
      expect(cocoClassNames, containsAll(['car', 'dog', 'cat', 'chair', 'laptop']));
    });
  });
}
