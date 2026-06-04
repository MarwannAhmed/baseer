import 'dart:math' as math;

import 'package:baseer/features/distance_estimation/domain/distance_estimate.dart';
import 'package:baseer/features/distance_estimation/domain/object_size_prior.dart';

class FusionUncertaintyEstimator {
  const FusionUncertaintyEstimator();

  DistanceEstimate fuse({
    required ObjectSizePrior prior,
    required double detectionConfidence,
    required double dHeight,
    required double dWidth,
    required double hPx,
    required double wPx,
    required double penalty,
  }) {
    final wHeight = prior.heightConfidence * penalty * detectionConfidence;
    final wWidth = prior.widthConfidence * penalty * detectionConfidence;
    final wSum = wHeight + wWidth;

    if (wSum <= 1e-6) {
      return const DistanceEstimate(
        distanceMeters: null,
        sigmaMeters: null,
        confidence: 0.0,
        error: 'low_confidence',
      );
    }

    final fused = (wHeight * dHeight + wWidth * dWidth) / wSum;

    final sigmaF = 0.03; // 3% focal-length uncertainty
    final sigmaPixel = 2.0;

    final sigmaHeight = _sigmaDistance(
      distance: dHeight,
      sigmaF: sigmaF,
      sigmaObj: prior.heightStdM / prior.typicalHeightM,
      sigmaPx: sigmaPixel / hPx,
    );

    final sigmaWidth = _sigmaDistance(
      distance: dWidth,
      sigmaF: sigmaF,
      sigmaObj: prior.widthStdM / prior.typicalWidthM,
      sigmaPx: sigmaPixel / wPx,
    );

    final sigmaFused = (wHeight * sigmaHeight + wWidth * sigmaWidth) / wSum;
    final confidence = math.min(1.0, wSum /
        (prior.heightConfidence + prior.widthConfidence));

    return DistanceEstimate(
      distanceMeters: fused,
      sigmaMeters: sigmaFused,
      confidence: confidence,
    );
  }

  double _sigmaDistance({
    required double distance,
    required double sigmaF,
    required double sigmaObj,
    required double sigmaPx,
  }) {
    final rel = math.sqrt(
      sigmaF * sigmaF + sigmaObj * sigmaObj + sigmaPx * sigmaPx,
    );
    return distance * rel;
  }
}
