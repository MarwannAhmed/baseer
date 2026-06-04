import 'package:baseer/features/analysis/domain/detected_object.dart';
import 'package:baseer/features/distance_estimation/application/method1/camera_intrinsics_manager.dart';
import 'package:baseer/features/distance_estimation/application/method2/camera_extrinsics_manager.dart';
import 'package:baseer/features/distance_estimation/application/method2/foot_point_selector.dart';
import 'package:baseer/features/distance_estimation/application/method2/geometric_confidence_estimator.dart';
import 'package:baseer/features/distance_estimation/application/method2/ray_ground_intersection_engine.dart';

class GroundPlaneProjectionEstimator {
  final CameraIntrinsicsManager _intrinsics;
  final CameraExtrinsicsManager _extrinsics;
  final FootPointSelector _footSelector;
  final RayGroundIntersectionEngine _intersectionEngine;
  final GeometricConfidenceEstimator _confidenceEstimator;

  static const double _minDistanceM = 0.3;
  static const double _maxDistanceM = 50.0;

  GroundPlaneProjectionEstimator({
    required double fovHorizontalDeg,
    required int imageWidth,
    required int imageHeight,
    required double cameraHeightM,
    required double pitchDeg,
  })  : _intrinsics = CameraIntrinsicsManager(
          fovHorizontalDeg: fovHorizontalDeg,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
        ),
        _extrinsics = CameraExtrinsicsManager(
          heightMeters: cameraHeightM,
          pitchDeg: pitchDeg,
        ),
        _footSelector = const FootPointSelector(),
        _intersectionEngine = const RayGroundIntersectionEngine(),
        _confidenceEstimator = const GeometricConfidenceEstimator(
          sigmaHeightMeters: 0.05,
          sigmaPitchDeg: 2.0,
        );

  List<DetectedObject> estimateForObjects({
    required List<DetectedObject> objects,
    required int imageWidth,
    required int imageHeight,
    required dynamic frame,
  }) {
    if (objects.isEmpty) return objects;
    _intrinsics.updateImageSize(imageWidth, imageHeight);

    final updated = <DetectedObject>[];
    for (final object in objects) {
      final x1 = object.bbox['x1'] ?? 0;
      final y1 = object.bbox['y1'] ?? 0;
      final x2 = object.bbox['x2'] ?? 0;
      final y2 = object.bbox['y2'] ?? 0;

      final footPoint = _footSelector.select(
        label: object.label,
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        imageHeight: imageHeight,
      );

      final intersection = _intersectionEngine.intersect(
        footPoint: footPoint,
        intrinsics: _intrinsics,
        extrinsics: _extrinsics,
      );

      final distance3d = intersection.distance3d;
      if (distance3d == null || distance3d.isNaN) {
        updated.add(object.copyWithDistance(distanceCm: -1));
        continue;
      }

      final clamped = distance3d.clamp(_minDistanceM, _maxDistanceM);
      final confidence = _confidenceEstimator.estimate(
        intersection: intersection,
        footPoint: footPoint,
        intrinsics: _intrinsics,
        extrinsics: _extrinsics,
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
