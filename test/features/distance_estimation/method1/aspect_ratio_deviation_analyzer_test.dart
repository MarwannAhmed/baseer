import 'package:flutter_test/flutter_test.dart';
import 'package:baseer/features/distance_estimation/application/method1/aspect_ratio_deviation_analyzer.dart';
import '../../../helpers/test_fixtures.dart';

void main() {
  const analyzer = AspectRatioDeviationAnalyzer();

  final personPrior = makeObjectSizePrior(
    typicalHeightM: 1.70,
    typicalWidthM: 0.45,
  );

  group('AspectRatioDeviationAnalyzer.compute()', () {
    test('returns penalty=0 and isClipped=false when hPx <= 0', () {
      final result = analyzer.compute(
        prior: personPrior,
        hPx: 0, wPx: 50,
        x1: 10, y1: 10, x2: 60, y2: 60,
        width: 640, height: 480,
      );
      expect(result.penalty, equals(0.0));
      expect(result.isClipped, isFalse);
    });

    test('returns penalty=0 when wPx <= 0', () {
      final result = analyzer.compute(
        prior: personPrior,
        hPx: 100, wPx: 0,
        x1: 10, y1: 10, x2: 60, y2: 60,
        width: 640, height: 480,
      );
      expect(result.penalty, equals(0.0));
    });

    test('penalty ≈ 1.0 when observed AR matches prior AR exactly', () {
      // expected AR = 1.70 / 0.45 ≈ 3.78; provide exactly matching pixel dims
      final expectedAR = personPrior.typicalHeightM / personPrior.typicalWidthM;
      final hPx = 100.0;
      final wPx = hPx / expectedAR;
      final result = analyzer.compute(
        prior: personPrior,
        hPx: hPx, wPx: wPx,
        x1: 10, y1: 10, x2: 50, y2: 110,
        width: 640, height: 480,
      );
      expect(result.penalty, closeTo(1.0, 0.01));
      expect(result.isClipped, isFalse);
    });

    test('large AR deviation produces penalty < 1.0', () {
      // Provide a very wide bbox relative to a tall prior → large deviation
      final result = analyzer.compute(
        prior: personPrior,
        hPx: 10, wPx: 200, // very wide
        x1: 10, y1: 10, x2: 210, y2: 20,
        width: 640, height: 480,
      );
      expect(result.penalty, lessThan(0.5));
    });

    test('isClipped=true when x1 == 0', () {
      final result = analyzer.compute(
        prior: personPrior,
        hPx: 100, wPx: 30,
        x1: 0, y1: 10, x2: 30, y2: 110,
        width: 640, height: 480,
      );
      expect(result.isClipped, isTrue);
    });

    test('isClipped=true when y1 == 0', () {
      final result = analyzer.compute(
        prior: personPrior,
        hPx: 100, wPx: 30,
        x1: 10, y1: 0, x2: 40, y2: 100,
        width: 640, height: 480,
      );
      expect(result.isClipped, isTrue);
    });

    test('isClipped=true when x2 >= width-1', () {
      final result = analyzer.compute(
        prior: personPrior,
        hPx: 100, wPx: 30,
        x1: 610, y1: 10, x2: 639, y2: 110,
        width: 640, height: 480,
      );
      expect(result.isClipped, isTrue);
    });

    test('clipping multiplies penalty by 0.1', () {
      final unclippedResult = analyzer.compute(
        prior: personPrior,
        hPx: 100, wPx: 100,
        x1: 10, y1: 10, x2: 110, y2: 110,
        width: 640, height: 480,
      );
      final clippedResult = analyzer.compute(
        prior: personPrior,
        hPx: 100, wPx: 100,
        x1: 0, y1: 10, x2: 100, y2: 110, // x1==0 → clipped
        width: 640, height: 480,
      );
      expect(
        clippedResult.penalty,
        closeTo(unclippedResult.penalty * 0.1, 0.001),
      );
    });

    test('isClipped=false when bbox is fully inside image', () {
      final result = analyzer.compute(
        prior: personPrior,
        hPx: 100, wPx: 30,
        x1: 10, y1: 10, x2: 40, y2: 110,
        width: 640, height: 480,
      );
      expect(result.isClipped, isFalse);
    });
  });
}
