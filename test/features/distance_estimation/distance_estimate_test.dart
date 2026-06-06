import 'package:flutter_test/flutter_test.dart';
import 'package:baseer/features/distance_estimation/domain/distance_estimate.dart';

void main() {
  group('DistanceEstimate', () {
    test('stores all fields correctly', () {
      const estimate = DistanceEstimate(
        dist: 3.5,
        std: 0.4,
        confidence: 0.85,
        error: null,
      );
      expect(estimate.dist, equals(3.5));
      expect(estimate.std, equals(0.4));
      expect(estimate.confidence, equals(0.85));
      expect(estimate.error, isNull);
    });

    test('dist can be null for low-confidence results', () {
      const estimate = DistanceEstimate(
        dist: null,
        std: null,
        confidence: 0.0,
        error: 'low_confidence',
      );
      expect(estimate.dist, isNull);
      expect(estimate.std, isNull);
      expect(estimate.error, equals('low_confidence'));
    });

    test('error field is optional and defaults to null', () {
      const estimate = DistanceEstimate(dist: 1.0, std: 0.1, confidence: 0.9);
      expect(estimate.error, isNull);
    });
  });
}
