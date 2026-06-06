import 'dart:math' as math;
import 'package:baseer/features/distance_estimation/domain/object_size_prior.dart';

class AspectRatioPenalty {

  final double penalty;
  final bool isClipped;

  const AspectRatioPenalty({
    required this.penalty,
    required this.isClipped,
  });

}

class AspectRatioDeviationAnalyzer {

  const AspectRatioDeviationAnalyzer();

  AspectRatioPenalty compute({
    required ObjectSizePrior prior,
    required double hPx,
    required double wPx,
    required int x1,
    required int y1,
    required int x2,
    required int y2,
    required int width,
    required int height,
  }) {
    if (hPx <= 0 || wPx <= 0) {
      return const AspectRatioPenalty(penalty: 0.0, isClipped: false);
    }
    final expected = prior.typicalHeightM / prior.typicalWidthM;
    final observed = hPx / wPx;
    final deviation = (observed - expected).abs() / expected;
    double penalty = math.exp(-2.0 * deviation);
    final isClipped = x1 <= 0 || y1 <= 0 || x2 >= width - 1 || y2 >= height - 1;
    if (isClipped) {
      penalty *= 0.1;
    }
    return AspectRatioPenalty(penalty: penalty, isClipped: isClipped);
  }

}