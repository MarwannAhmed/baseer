import 'package:baseer/features/analysis/domain/detected_object.dart';
import 'package:baseer/features/distance_estimation/application/method1/camera_intrinsics_manager.dart';
import 'package:baseer/features/distance_estimation/application/method2/camera_extrinsics_manager.dart';
import 'package:baseer/features/distance_estimation/application/method2/foot_point_selector.dart';
import 'package:baseer/features/distance_estimation/application/method2/geometric_confidence_estimator.dart';
import 'package:baseer/features/distance_estimation/application/method2/ray_ground_intersection_engine.dart';

class GroundPlaneProjectionEstimator {

  final CameraIntrinsicsManager intrinsics;
  final CameraExtrinsicsManager extrinsics;
  final FootPointSelector footSelector;
  final RayGroundIntersectionEngine intersectionEngine;
  final GeometricConfidenceEstimator confidenceEstimator;

  GroundPlaneProjectionEstimator({
    required int width,
    required int height,
  })  : intrinsics = CameraIntrinsicsManager(
          width: width,
          height: height,
        ),
        extrinsics = CameraExtrinsicsManager(),
        footSelector = const FootPointSelector(),
        intersectionEngine = const RayGroundIntersectionEngine(),
        confidenceEstimator = const GeometricConfidenceEstimator();

  List<DetectedObject> estimateForObjects({
    required List<DetectedObject> objects,
    required int width,
    required int height,
    required dynamic frame,
  }) {
    if (objects.isEmpty) return objects;
    intrinsics.updateImageSize(width, height);
    final updated = <DetectedObject>[];
    for (final object in objects) {
      final x1 = object.bbox['x1'] ?? 0;
      final y1 = object.bbox['y1'] ?? 0;
      final x2 = object.bbox['x2'] ?? 0;
      final y2 = object.bbox['y2'] ?? 0;
      final footPoint = footSelector.select(
        label: object.label,
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        imageHeight: height,
      );
      final intersection = intersectionEngine.intersect(
        footPoint: footPoint,
        intrinsics: intrinsics,
        extrinsics: extrinsics,
      );
      final distance3d = intersection.distance3d;
      if (distance3d == null || distance3d.isNaN) {
        updated.add(object.copyWithDistance(distanceCm: -1));
        continue;
      }
      final clamped = distance3d.clamp(0.2, 50);
      final confidence = confidenceEstimator.estimate(
        intersection: intersection,
        footPoint: footPoint,
        intrinsics: intrinsics,
        extrinsics: extrinsics,
      );
      if (confidence.confidence <= 0.0) {
        updated.add(object.copyWithDistance(distanceCm: -1));
        continue;
      }
      updated.add(object.copyWithDistance(distanceCm: (clamped * 100).round()));
    }
    return updated;
  }

}