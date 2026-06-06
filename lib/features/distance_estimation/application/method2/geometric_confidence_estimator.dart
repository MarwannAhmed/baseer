import 'dart:math' as math;
import 'package:baseer/features/distance_estimation/application/method1/camera_intrinsics_manager.dart';
import 'package:baseer/features/distance_estimation/application/method2/camera_extrinsics_manager.dart';
import 'package:baseer/features/distance_estimation/application/method2/foot_point_selector.dart';
import 'package:baseer/features/distance_estimation/application/method2/ray_ground_intersection_engine.dart';

class GeometricConfidenceResult {

  final double confidence;
  final double? std;

  const GeometricConfidenceResult({
    required this.confidence,
    required this.std,
  });

}

class GeometricConfidenceEstimator {

  final double stdH;
  final double stdPitch;

  const GeometricConfidenceEstimator()
    : stdH = 0.05,
      stdPitch = 2.0;

  GeometricConfidenceResult estimate({
    required GroundIntersectionResult intersection,
    required FootPoint footPoint,
    required CameraIntrinsicsManager intrinsics,
    required CameraExtrinsicsManager extrinsics,
  }) {
    if (intersection.distance3d == null || intersection.rayYWorld == null || intersection.rayXWorld == null || intersection.rayZWorld == null) {
      return const GeometricConfidenceResult(
        confidence: 0.0,
        std: null,
      );
    }
    final rayY = intersection.rayYWorld!;
    final rayX = intersection.rayXWorld!;
    final rayZ = intersection.rayZWorld!;
    final rad = math.atan2(-rayY, math.sqrt(rayX * rayX + rayZ * rayZ));
    final deg = rad * 180.0 / math.pi;
    final confidence = angleToConfidence(deg);
    final std = calcStd(
      footPoint: footPoint,
      intrinsics: intrinsics,
      extrinsics: extrinsics,
    );
    return GeometricConfidenceResult(
      confidence: confidence,
      std: std,
    );
  }

  double angleToConfidence(double deg) {
    if (deg <= 2.0) return 0.15;
    if (deg >= 10.0) return 0.88;
    final t = (deg - 2.0) / (10.0 - 2.0);
    return 0.15 + t * (0.88 - 0.15);
  }

  double? calcStd({
    required FootPoint footPoint,
    required CameraIntrinsicsManager intrinsics,
    required CameraExtrinsicsManager extrinsics,
  }) {
    const epsH = 0.01;
    final epsTheta = (1.0 * math.pi / 180.0);
    final baseH = extrinsics.hCam;
    final baseP = extrinsics.pitchRad;
    final dUp = distanceWithParams(
      footPoint: footPoint,
      intrinsics: intrinsics,
      height: baseH + epsH,
      pitch: baseP,
    );
    final dDown = distanceWithParams(
      footPoint: footPoint,
      intrinsics: intrinsics,
      height: baseH - epsH,
      pitch: baseP,
    );
    if (dUp.isNaN || dDown.isNaN) return null;
    final dHeight = (dUp - dDown) / (2 * epsH);
    final dLeft = distanceWithParams(
      footPoint: footPoint,
      intrinsics: intrinsics,
      height: baseH,
      pitch: baseP + epsTheta,
    );
    final dRight = distanceWithParams(
      footPoint: footPoint,
      intrinsics: intrinsics,
      height: baseH,
      pitch: baseP - epsTheta,
    );
    if (dLeft.isNaN || dRight.isNaN) return null;
    final dTheta = (dLeft - dRight) / (2 * epsTheta);
    final sigmaThetaRad = stdPitch * math.pi / 180.0;
    return math.sqrt((dHeight * stdH) * (dHeight * stdH) + (dTheta * sigmaThetaRad) * (dTheta * sigmaThetaRad),);
  }

  double distanceWithParams({
    required FootPoint footPoint,
    required CameraIntrinsicsManager intrinsics,
    required double height,
    required double pitch,
  }) {
    final cx = intrinsics.width / 2.0;
    final cy = intrinsics.height / 2.0;
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
