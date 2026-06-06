import 'package:flutter_test/flutter_test.dart';
import 'package:baseer/features/distance_estimation/application/method1/dual_hypothesis_distance_calculator.dart';
import '../../../helpers/test_fixtures.dart';

void main() {
  const calc = DualHypothesisDistanceCalculator();

  group('DualHypothesisDistanceCalculator.compute()', () {
    final personPrior = makeObjectSizePrior(
      typicalHeightM: 1.70,
      typicalWidthM: 0.45,
    );

    test('returns null when hPx <= 0', () {
      final result = calc.compute(
        prior: personPrior, fPx: 500, fPy: 500,
        hPx: 0, wPx: 100,
      );
      expect(result, isNull);
    });

    test('returns null when wPx <= 0', () {
      final result = calc.compute(
        prior: personPrior, fPx: 500, fPy: 500,
        hPx: 100, wPx: 0,
      );
      expect(result, isNull);
    });

    test('returns null when both hPx and wPx are negative', () {
      final result = calc.compute(
        prior: personPrior, fPx: 500, fPy: 500,
        hPx: -10, wPx: -10,
      );
      expect(result, isNull);
    });

    test('heightDist = fPy * typicalHeightM / hPx', () {
      final result = calc.compute(
        prior: personPrior, fPx: 500, fPy: 500,
        hPx: 200, wPx: 60,
      );
      final expected = 500.0 * 1.70 / 200.0;
      expect(result!.heightDist, closeTo(expected, 0.001));
    });

    test('widthDist = fPx * typicalWidthM / wPx', () {
      final result = calc.compute(
        prior: personPrior, fPx: 500, fPy: 500,
        hPx: 200, wPx: 150,
      );
      final expected = 500.0 * 0.45 / 150.0;
      expect(result!.widthDist, closeTo(expected, 0.001));
    });

    test('concrete example: fPy=500, H=1.70m, hPx=200 → heightDist=4.25m', () {
      final result = calc.compute(
        prior: personPrior, fPx: 500, fPy: 500,
        hPx: 200, wPx: 100,
      );
      expect(result!.heightDist, closeTo(4.25, 0.001));
    });

    test('returns non-null DualHypothesisDistance when both dims are positive', () {
      final result = calc.compute(
        prior: personPrior, fPx: 400, fPy: 400,
        hPx: 150, wPx: 50,
      );
      expect(result, isNotNull);
      expect(result!.heightDist, isPositive);
      expect(result.widthDist, isPositive);
    });
  });
}
