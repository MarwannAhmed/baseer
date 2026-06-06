import 'package:flutter_test/flutter_test.dart';
import 'package:baseer/features/distance_estimation/application/method1/object_size_prior_database.dart';
import 'package:baseer/features/object_detection/domain/coco_labels.dart';

void main() {
  group('ObjectSizePriorDatabase', () {
    late ObjectSizePriorDatabase db;

    setUp(() {
      db = ObjectSizePriorDatabase.coco80();
    });

    test('covers all 80 COCO class names', () {
      for (final label in cocoClassNames) {
        final prior = db.getPrior(label);
        expect(prior.className, isNotEmpty);
      }
    });

    test('getPrior(person) returns correct height', () {
      expect(db.getPrior('person').typicalHeightM, closeTo(1.70, 0.001));
    });

    test('getPrior(person) returns correct width', () {
      expect(db.getPrior('person').typicalWidthM, closeTo(0.45, 0.001));
    });

    test('getPrior(person) has high height confidence', () {
      expect(db.getPrior('person').heightConfidence, greaterThan(0.80));
    });

    test('getPrior(car) returns expected height', () {
      expect(db.getPrior('car').typicalHeightM, closeTo(1.50, 0.001));
    });

    test('getPrior(unknown_xyz) returns fallback with H=1.0m', () {
      expect(db.getPrior('unknown_xyz').typicalHeightM, equals(1.0));
    });

    test('getPrior(unknown_xyz) returns fallback with W=0.5m', () {
      expect(db.getPrior('unknown_xyz').typicalWidthM, equals(0.5));
    });

    test('all 80 priors have typicalHeightM > 0', () {
      for (final label in cocoClassNames) {
        expect(db.getPrior(label).typicalHeightM, isPositive,
            reason: 'Failed for label: $label');
      }
    });

    test('all 80 priors have typicalWidthM > 0', () {
      for (final label in cocoClassNames) {
        expect(db.getPrior(label).typicalWidthM, isPositive,
            reason: 'Failed for label: $label');
      }
    });

    test('all 80 priors have heightConfidence > 0', () {
      for (final label in cocoClassNames) {
        expect(db.getPrior(label).heightConfidence, isPositive,
            reason: 'Failed for label: $label');
      }
    });
  });
}
