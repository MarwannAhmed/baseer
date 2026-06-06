import 'package:baseer/features/analysis/domain/detected_object.dart';
import 'package:baseer/features/distance_estimation/application/method1/aspect_ratio_deviation_analyzer.dart';
import 'package:baseer/features/distance_estimation/application/method1/camera_intrinsics_manager.dart';
import 'package:baseer/features/distance_estimation/application/method1/dual_hypothesis_distance_calculator.dart';
import 'package:baseer/features/distance_estimation/application/method1/focal_length_refiner.dart';
import 'package:baseer/features/distance_estimation/application/method1/fusion_uncertainty_estimator.dart';
import 'package:baseer/features/distance_estimation/application/method1/object_size_prior_database.dart';

class PinholePriorDistanceEstimator {

  final ObjectSizePriorDatabase database;
  final CameraIntrinsicsManager intrinsics;
  final DualHypothesisDistanceCalculator dualCalculator;
  final AspectRatioDeviationAnalyzer aspectAnalyzer;
  final FusionUncertaintyEstimator fusionEstimator;
  final FocalLengthRefiner focalRefiner;

  PinholePriorDistanceEstimator({
    required int width,
    required int height,
  })  : database = ObjectSizePriorDatabase.coco80(),
        intrinsics = CameraIntrinsicsManager(
          width: width,
          height: height,
        ),
        dualCalculator = const DualHypothesisDistanceCalculator(),
        aspectAnalyzer = const AspectRatioDeviationAnalyzer(),
        fusionEstimator = const FusionUncertaintyEstimator(),
        focalRefiner = FocalLengthRefiner();

  List<DetectedObject> estimateForObjects({
    required List<DetectedObject> objects,
    required int width,
    required int height,
    required dynamic frame,
  }) {
    if (objects.isEmpty) return objects;
    intrinsics.updateImageSize(width, height);
    final List<DetectedObject> objectsWithDistance = [];
    for (final object in objects) {
      final x1 = object.bbox['x1'] ?? 0;
      final y1 = object.bbox['y1'] ?? 0;
      final x2 = object.bbox['x2'] ?? 0;
      final y2 = object.bbox['y2'] ?? 0;
      final hPx = (y2 - y1).toDouble();
      final wPx = (x2 - x1).toDouble();
      if (hPx < 10.0 || wPx < 10.0) {
        objectsWithDistance.add(object.copyWithDistance(distanceCm: -1));
        continue;
      }
      final prior = database.getPrior(object.label);
      final dual = dualCalculator.compute(
        prior: prior,
        fPx: intrinsics.fPx,
        fPy: intrinsics.fPy,
        hPx: hPx,
        wPx: wPx,
      );
      if (dual == null) {
        objectsWithDistance.add(object.copyWithDistance(distanceCm: -1));
        continue;
      }
      final penalty = aspectAnalyzer.compute(
        prior: prior,
        hPx: hPx,
        wPx: wPx,
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        width: width,
        height: height,
      );
      final fused = fusionEstimator.fuse(
        prior: prior,
        detectionConfidence: object.confidence,
        heightDist: dual.heightDist,
        widthDist: dual.widthDist,
        hPx: hPx,
        wPx: wPx,
        penalty: penalty.penalty,
      );
      final dist = fused.dist;
      if (dist == null || dist.isNaN) {
        objectsWithDistance.add(object.copyWithDistance(distanceCm: -1));
        continue;
      }
      final clamped = dist.clamp(0.2, 50.0);
      final distanceCm = (clamped * 100).round();
      focalRefiner.consider(
        detectionConfidence: object.confidence,
        prior: prior,
        dist: clamped,
        height: hPx,
        isClipped: penalty.isClipped,
        intrinsics: intrinsics,
      );
      objectsWithDistance.add(object.copyWithDistance(distanceCm: distanceCm));
    }
    return objectsWithDistance;
  }

}