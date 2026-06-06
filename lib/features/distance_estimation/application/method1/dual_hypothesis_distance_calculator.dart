import 'package:baseer/features/distance_estimation/domain/object_size_prior.dart';

class DualHypothesisDistance {

  final double heightDist;
  final double widthDist;

  const DualHypothesisDistance({
    required this.heightDist,
    required this.widthDist,
  });

}

class DualHypothesisDistanceCalculator {

  const DualHypothesisDistanceCalculator();

  DualHypothesisDistance? compute({
    required ObjectSizePrior prior,
    required double fPx,
    required double fPy,
    required double hPx,
    required double wPx,
  }) {
    if (hPx <= 0 || wPx <= 0) return null;
    final dHeight = (fPy * prior.typicalHeightM) / hPx;
    final dWidth = (fPx * prior.typicalWidthM) / wPx;
    return DualHypothesisDistance(
      heightDist: dHeight,
      widthDist: dWidth,
    );
  }

}