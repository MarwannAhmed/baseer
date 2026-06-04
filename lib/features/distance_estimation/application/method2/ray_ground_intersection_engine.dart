import 'dart:math' as math;

import 'package:baseer/features/distance_estimation/application/method1/camera_intrinsics_manager.dart';
import 'package:baseer/features/distance_estimation/application/method2/camera_extrinsics_manager.dart';
import 'package:baseer/features/distance_estimation/application/method2/foot_point_selector.dart';

class GroundIntersectionResult {
  final double? distanceGround;
  final double? distance3d;
  final double? rayYWorld;
  final double? rayXWorld;
  final double? rayZWorld;
  final String? error;

  const GroundIntersectionResult({
    required this.distanceGround,
    required this.distance3d,
    required this.rayYWorld,
    required this.rayXWorld,
    required this.rayZWorld,
    this.error,
  });
}

class RayGroundIntersectionEngine {
  const RayGroundIntersectionEngine();

  GroundIntersectionResult intersect({
    required FootPoint footPoint,
    required CameraIntrinsicsManager intrinsics,
    required CameraExtrinsicsManager extrinsics,
  }) {
    final cx = intrinsics.imageWidth / 2.0;
    final cy = intrinsics.imageHeight / 2.0;
    final fPx = intrinsics.fPx;
    final fPy = intrinsics.fPy;

    final rxCam = (footPoint.u - cx) / fPx;
    final ryCam = (cy - footPoint.v) / fPy;
    final rzCam = 1.0;

    final pitch = extrinsics.pitchRad;

    final rxWorld = rxCam;
    final ryWorld = ryCam * math.cos(pitch) - rzCam * math.sin(pitch);
    final rzWorld = ryCam * math.sin(pitch) + rzCam * math.cos(pitch);

    if (ryWorld >= -1e-6) {
      return const GroundIntersectionResult(
        distanceGround: null,
        distance3d: null,
        rayYWorld: null,
        rayXWorld: null,
        rayZWorld: null,
        error: 'ray_no_ground_intersection',
      );
    }

    final t = -extrinsics.heightMeters / ryWorld;
    final xWorld = t * rxWorld;
    final zWorld = t * rzWorld;
    final distanceGround = math.sqrt(xWorld * xWorld + zWorld * zWorld);
    final distance3d = math.sqrt(
      distanceGround * distanceGround +
          extrinsics.heightMeters * extrinsics.heightMeters,
    );

    return GroundIntersectionResult(
      distanceGround: distanceGround,
      distance3d: distance3d,
      rayYWorld: ryWorld,
      rayXWorld: rxWorld,
      rayZWorld: rzWorld,
    );
  }
}
