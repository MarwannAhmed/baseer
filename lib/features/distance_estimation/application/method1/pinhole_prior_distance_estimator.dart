import 'package:baseer/features/analysis/domain/detected_object.dart';
import 'package:baseer/features/distance_estimation/application/method1/aspect_ratio_deviation_analyzer.dart';
import 'package:baseer/features/distance_estimation/application/method1/camera_intrinsics_manager.dart';
import 'package:baseer/features/distance_estimation/application/method1/dual_hypothesis_distance_calculator.dart';
import 'package:baseer/features/distance_estimation/application/method1/focal_length_refiner.dart';
import 'package:baseer/features/distance_estimation/application/method1/fusion_uncertainty_estimator.dart';
import 'package:baseer/features/distance_estimation/application/method1/object_size_prior_database.dart';

class PinholePriorDistanceEstimator {
  final ObjectSizePriorDatabase _database;
  final CameraIntrinsicsManager _intrinsics;
  final DualHypothesisDistanceCalculator _dualCalculator;
  final AspectRatioDeviationAnalyzer _aspectAnalyzer;
  final FusionUncertaintyEstimator _fusionEstimator;
  final FocalLengthRefiner _focalRefiner;

  static const double _minDistanceM = 0.2;
  static const double _maxDistanceM = 50.0;
  static const double _minBboxPixels = 10.0;

  PinholePriorDistanceEstimator({
    required double fovHorizontalDeg,
    required int imageWidth,
    required int imageHeight,
  })  : _database = ObjectSizePriorDatabase.coco80(),
        _intrinsics = CameraIntrinsicsManager(
          fovHorizontalDeg: fovHorizontalDeg,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
        ),
        _dualCalculator = const DualHypothesisDistanceCalculator(),
        _aspectAnalyzer = const AspectRatioDeviationAnalyzer(),
        _fusionEstimator = const FusionUncertaintyEstimator(),
        _focalRefiner = FocalLengthRefiner();

  List<DetectedObject> estimateForObjects({
    required List<DetectedObject> objects,
    required int imageWidth,
    required int imageHeight,
    required dynamic frame,
  }) {
    if (objects.isEmpty) return objects;

    _intrinsics.updateImageSize(imageWidth, imageHeight);

    final List<DetectedObject> updated = [];
    for (final object in objects) {
      final x1 = object.bbox['x1'] ?? 0;
      final y1 = object.bbox['y1'] ?? 0;
      final x2 = object.bbox['x2'] ?? 0;
      final y2 = object.bbox['y2'] ?? 0;

      final hPx = (y2 - y1).toDouble();
      final wPx = (x2 - x1).toDouble();

      if (hPx < _minBboxPixels || wPx < _minBboxPixels) {
        updated.add(object.copyWithDistance(distanceCm: -1));
        continue;
      }

      final prior = _database.getPrior(object.label);
      final dual = _dualCalculator.compute(
        prior: prior,
        fPx: _intrinsics.fPx,
        fPy: _intrinsics.fPy,
        hPx: hPx,
        wPx: wPx,
      );

      if (dual == null) {
        updated.add(object.copyWithDistance(distanceCm: -1));
        continue;
      }

      final penalty = _aspectAnalyzer.compute(
        prior: prior,
        hPx: hPx,
        wPx: wPx,
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );

      final fused = _fusionEstimator.fuse(
        prior: prior,
        detectionConfidence: object.confidence,
        dHeight: dual.heightMeters,
        dWidth: dual.widthMeters,
        hPx: hPx,
        wPx: wPx,
        penalty: penalty.penalty,
      );

      final distanceMeters = fused.distanceMeters;
      if (distanceMeters == null || distanceMeters.isNaN) {
        updated.add(object.copyWithDistance(distanceCm: -1));
        continue;
      }

      final clamped = distanceMeters.clamp(_minDistanceM, _maxDistanceM);
      final distanceCm = (clamped * 100).round();

      _focalRefiner.consider(
        detectionConfidence: object.confidence,
        prior: prior,
        distanceMeters: clamped,
        heightPx: hPx,
        isClipped: penalty.isClipped,
        intrinsics: _intrinsics,
      );

      updated.add(object.copyWithDistance(distanceCm: distanceCm));
    }

    return updated;
  }
}
