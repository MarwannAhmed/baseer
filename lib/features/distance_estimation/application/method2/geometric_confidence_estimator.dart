import 'dart:math' as math;

import 'package:baseer/features/distance_estimation/application/method1/camera_intrinsics_manager.dart';
import 'package:baseer/features/distance_estimation/application/method2/camera_extrinsics_manager.dart';
import 'package:baseer/features/distance_estimation/application/method2/foot_point_selector.dart';
import 'package:baseer/features/distance_estimation/application/method2/ray_ground_intersection_engine.dart';

class GeometricConfidenceResult {
  final double confidence;
  final double? sigmaMeters;

  const GeometricConfidenceResult({
    required this.confidence,
    required this.sigmaMeters,
  });
}

class GeometricConfidenceEstimator {
  final double sigmaHeightMeters;
  final double sigmaPitchDeg;

  const GeometricConfidenceEstimator({
    required this.sigmaHeightMeters,
    required this.sigmaPitchDeg,
  });

  GeometricConfidenceResult estimate({
    required GroundIntersectionResult intersection,
    required FootPoint footPoint,
    required CameraIntrinsicsManager intrinsics,
    required CameraExtrinsicsManager extrinsics,
  }) {
    if (intersection.distance3d == null ||
        intersection.rayYWorld == null ||
        intersection.rayXWorld == null ||
        intersection.rayZWorld == null) {
      return const GeometricConfidenceResult(
        confidence: 0.0,
        sigmaMeters: null,
      );
    }

    final rayY = intersection.rayYWorld!;
    final rayX = intersection.rayXWorld!;
    final rayZ = intersection.rayZWorld!;

    final angleRad = math.atan2(-rayY, math.sqrt(rayX * rayX + rayZ * rayZ));
    final angleDeg = angleRad * 180.0 / math.pi;
    final confidence = _angleToConfidence(angleDeg);

    final sigmaMeters = _estimateSigma(
      footPoint: footPoint,
      intrinsics: intrinsics,
      extrinsics: extrinsics,
    );

    return GeometricConfidenceResult(
      confidence: confidence,
      sigmaMeters: sigmaMeters,
    );
  }

  double _angleToConfidence(double angleDeg) {
    if (angleDeg <= 2.0) return 0.15;
    if (angleDeg >= 10.0) return 0.88;
    final t = (angleDeg - 2.0) / (10.0 - 2.0);
    return 0.15 + t * (0.88 - 0.15);
  }

  double? _estimateSigma({
    required FootPoint footPoint,
    required CameraIntrinsicsManager intrinsics,
    required CameraExtrinsicsManager extrinsics,
  }) {
    const epsH = 0.01;
    final epsTheta = (1.0 * math.pi / 180.0);

    final baseHeight = extrinsics.heightMeters;
    final basePitch = extrinsics.pitchRad;

    final dUp = _distanceWithParams(
      footPoint: footPoint,
      intrinsics: intrinsics,
      height: baseHeight + epsH,
      pitch: basePitch,
    );
    final dDown = _distanceWithParams(
      footPoint: footPoint,
      intrinsics: intrinsics,
      height: baseHeight - epsH,
      pitch: basePitch,
    );
    if (dUp.isNaN || dDown.isNaN) return null;
    final dHeight = (dUp - dDown) / (2 * epsH);

    final dLeft = _distanceWithParams(
      footPoint: footPoint,
      intrinsics: intrinsics,
      height: baseHeight,
      pitch: basePitch + epsTheta,
    );
    final dRight = _distanceWithParams(
      footPoint: footPoint,
      intrinsics: intrinsics,
      height: baseHeight,
      pitch: basePitch - epsTheta,
    );
    if (dLeft.isNaN || dRight.isNaN) return null;
    final dTheta = (dLeft - dRight) / (2 * epsTheta);

    final sigmaThetaRad = sigmaPitchDeg * math.pi / 180.0;
    return math.sqrt(
      (dHeight * sigmaHeightMeters) * (dHeight * sigmaHeightMeters) +
          (dTheta * sigmaThetaRad) * (dTheta * sigmaThetaRad),
    );
  }

  double _distanceWithParams({
    required FootPoint footPoint,
    required CameraIntrinsicsManager intrinsics,
    required double height,
    required double pitch,
  }) {
    final cx = intrinsics.imageWidth / 2.0;
    final cy = intrinsics.imageHeight / 2.0;
    final fPx = intrinsics.fPx;
    final fPy = intrinsics.fPy;

    final rxCam = (footPoint.u - cx) / fPx;
    final ryCam = (cy - footPoint.v) / fPy;
    final rzCam = 1.0;

    final ryWorld = ryCam * math.cos(pitch) - rzCam * math.sin(pitch);
    final rzWorld = ryCam * math.sin(pitch) + rzCam * math.cos(pitch);

    if (ryWorld >= -1e-6) return double.nan;

    final t = -height / ryWorld;
    final xWorld = t * rxCam;
    final zWorld = t * rzWorld;
    final distanceGround = math.sqrt(xWorld * xWorld + zWorld * zWorld);
    return math.sqrt(distanceGround * distanceGround + height * height);
  }
}
