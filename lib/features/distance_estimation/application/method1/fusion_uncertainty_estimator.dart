import 'dart:math' as math;
import 'package:baseer/features/distance_estimation/domain/distance_estimate.dart';
import 'package:baseer/features/distance_estimation/domain/object_size_prior.dart';

class FusionUncertaintyEstimator {

  const FusionUncertaintyEstimator();

  double calcDistanceStd({
    required double distance,
    required double stdF,
    required double stdObj,
    required double stdP,
  }) {
    final rel = math.sqrt(
      stdF * stdF + stdObj * stdObj + stdP * stdP,
    );
    return distance * rel;
  }

  DistanceEstimate fuse({
    required ObjectSizePrior prior,
    required double detectionConfidence,
    required double heightDist,
    required double widthDist,
    required double hPx,
    required double wPx,
    required double penalty,
  }) {
    final heightWeight = prior.heightConfidence * penalty * detectionConfidence;
    final widthWeight = prior.widthConfidence * penalty * detectionConfidence;
    final weightSum = heightWeight + widthWeight;
    if (weightSum <= 1e-6) {
      return const DistanceEstimate(
        dist: null,
        std: null,
        confidence: 0.0,
        error: 'low_confidence',
      );
    }
    final fused = (heightWeight * heightDist + widthWeight * widthDist) / weightSum;
    final stdF = 0.03;
    final stdP = 2.0;
    final stdH = calcDistanceStd(
      distance: heightDist,
      stdF: stdF,
      stdObj: prior.heightStdM / prior.typicalHeightM,
      stdP: stdP / hPx,
    );
    final stdW = calcDistanceStd(
      distance: widthDist,
      stdF: stdF,
      stdObj: prior.widthStdM / prior.typicalWidthM,
      stdP: stdP / wPx,
    );
    final sigmaFused = (heightWeight * stdH + widthWeight * stdW) / weightSum;
    final confidence = math.min(1.0, weightSum / (prior.heightConfidence + prior.widthConfidence));
    return DistanceEstimate(
      dist: fused,
      std: sigmaFused,
      confidence: confidence,
    );
  }

}