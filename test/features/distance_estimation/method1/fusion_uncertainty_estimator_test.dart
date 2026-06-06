import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:baseer/features/distance_estimation/application/method1/fusion_uncertainty_estimator.dart';
import '../../../helpers/test_fixtures.dart';

void main() {
  const fuser = FusionUncertaintyEstimator();

  group('FusionUncertaintyEstimator', () {
    final prior = makeObjectSizePrior(
      typicalHeightM: 1.70,
      typicalWidthM: 0.45,
      heightStdM: 0.12,
      widthStdM: 0.10,
      heightConfidence: 0.85,
      widthConfidence: 0.60,
    );

    group('fuse()', () {
      test('returns low_confidence estimate when all weights are zero', () {
        final zeroPrior = makeObjectSizePrior(
          heightConfidence: 0.0,
          widthConfidence: 0.0,
        );
        final result = fuser.fuse(
          prior: zeroPrior,
          detectionConfidence: 0.9,
          heightDist: 3.0,
          widthDist: 3.0,
          hPx: 100,
          wPx: 50,
          penalty: 1.0,
        );
        expect(result.dist, isNull);
        expect(result.error, equals('low_confidence'));
        expect(result.confidence, equals(0.0));
      });

      test('height-only: fused dist equals heightDist when widthConfidence=0', () {
        final heightOnlyPrior = makeObjectSizePrior(
          heightConfidence: 0.85,
          widthConfidence: 0.0,
        );
        final result = fuser.fuse(
          prior: heightOnlyPrior,
          detectionConfidence: 0.9,
          heightDist: 4.0,
          widthDist: 2.0,
          hPx: 100,
          wPx: 50,
          penalty: 1.0,
        );
        expect(result.dist, closeTo(4.0, 0.01));
      });

      test('equal confidences: fused dist is weighted average', () {
        final equalPrior = makeObjectSizePrior(
          heightConfidence: 0.5,
          widthConfidence: 0.5,
        );
        final result = fuser.fuse(
          prior: equalPrior,
          detectionConfidence: 1.0,
          heightDist: 4.0,
          widthDist: 2.0,
          hPx: 100,
          wPx: 50,
          penalty: 1.0,
        );
        expect(result.dist, closeTo(3.0, 0.01)); // (4+2)/2
      });

      test('confidence is clamped to 1.0', () {
        final result = fuser.fuse(
          prior: prior,
          detectionConfidence: 1.0,
          heightDist: 3.0,
          widthDist: 3.0,
          hPx: 200,
          wPx: 60,
          penalty: 1.0,
        );
        expect(result.confidence, lessThanOrEqualTo(1.0));
      });

      test('std is positive when both dists are positive', () {
        final result = fuser.fuse(
          prior: prior,
          detectionConfidence: 0.9,
          heightDist: 3.0,
          widthDist: 3.0,
          hPx: 100,
          wPx: 50,
          penalty: 1.0,
        );
        expect(result.std, isNotNull);
        expect(result.std!, isPositive);
      });
    });

    group('calcDistanceStd()', () {
      test('returns 0 when distance is 0', () {
        final std = fuser.calcDistanceStd(
          distance: 0.0,
          stdF: 0.03,
          stdObj: 0.1,
          stdP: 0.05,
        );
        expect(std, equals(0.0));
      });

      test('formula: distance * sqrt(stdF² + stdObj² + stdP²)', () {
        const distance = 5.0;
        const stdF = 0.03;
        const stdObj = 0.1;
        const stdP = 0.05;
        final expected =
            distance * math.sqrt(stdF * stdF + stdObj * stdObj + stdP * stdP);
        final result = fuser.calcDistanceStd(
          distance: distance,
          stdF: stdF,
          stdObj: stdObj,
          stdP: stdP,
        );
        expect(result, closeTo(expected, 0.0001));
      });
    });
  });
}
