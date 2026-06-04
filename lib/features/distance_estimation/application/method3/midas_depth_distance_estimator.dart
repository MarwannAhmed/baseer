import 'dart:math' as math;

import 'package:baseer/features/analysis/domain/detected_object.dart';
import 'package:baseer/features/distance_estimation/application/method1/camera_intrinsics_manager.dart';
import 'package:baseer/features/distance_estimation/application/method1/object_size_prior_database.dart';
import 'package:baseer/features/distance_estimation/application/method1/pinhole_prior_distance_estimator.dart';
import 'package:baseer/features/distance_estimation/application/method2/camera_extrinsics_manager.dart';
import 'package:baseer/features/distance_estimation/application/method2/foot_point_selector.dart';
import 'package:baseer/features/distance_estimation/application/method2/geometric_confidence_estimator.dart';
import 'package:baseer/features/distance_estimation/application/method2/ray_ground_intersection_engine.dart';
import 'package:baseer/features/distance_estimation/application/method3/midas_depth_engine.dart';
import 'package:baseer/features/distance_estimation/application/method3/weighted_median_fuser.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class MidasDepthDistanceEstimator {
  final MidasDepthEngine _engine;
  final CameraIntrinsicsManager _intrinsics;
  final CameraExtrinsicsManager _extrinsics;
  final RayGroundIntersectionEngine _intersectionEngine;
  final GeometricConfidenceEstimator _confidenceEstimator;
  final ObjectSizePriorDatabase _priorDatabase;
  final PinholePriorDistanceEstimator _pinholeEstimator;
  final WeightedMedianFuser _fuser;

  final double _emaAlpha;
  final double _groundStartRatio;
  final int _groundStridePx;

  double? _scaleEma;

  static const double _minDistanceM = 0.3;
  static const double _maxDistanceM = 50.0;
  static const double _minRelDepth = 1e-6;

  MidasDepthDistanceEstimator({
    required String modelAssetPath,
    required int modelInputSize,
    required int threads,
    required double fovHorizontalDeg,
    required int imageWidth,
    required int imageHeight,
    required double cameraHeightM,
    required double pitchDeg,
    required double emaAlpha,
    required double groundStartRatio,
    required int groundStridePx,
  })  : _engine = MidasDepthEngine(
          assetPath: modelAssetPath,
          inputSize: modelInputSize,
          threads: threads,
        ),
        _intrinsics = CameraIntrinsicsManager(
          fovHorizontalDeg: fovHorizontalDeg,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
        ),
        _extrinsics = CameraExtrinsicsManager(
          heightMeters: cameraHeightM,
          pitchDeg: pitchDeg,
        ),
        _intersectionEngine = const RayGroundIntersectionEngine(),
        _confidenceEstimator = const GeometricConfidenceEstimator(
          sigmaHeightMeters: 0.05,
          sigmaPitchDeg: 2.0,
        ),
        _priorDatabase = ObjectSizePriorDatabase.coco80(),
        _pinholeEstimator = PinholePriorDistanceEstimator(
          fovHorizontalDeg: fovHorizontalDeg,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
        ),
        _fuser = const WeightedMedianFuser(),
        _emaAlpha = emaAlpha,
        _groundStartRatio = groundStartRatio,
        _groundStridePx = groundStridePx;

  Future<List<DetectedObject>> estimateForObjects({
    required List<DetectedObject> objects,
    required int imageWidth,
    required int imageHeight,
    required dynamic frame,
  }) async {
    if (objects.isEmpty) return objects;
    if (frame is! img.Image) {
      debugPrint('[MiDaS] Frame is not an image. Skipping.');
      return objects.map((o) => o.copyWithDistance(distanceCm: -1)).toList();
    }

    _intrinsics.updateImageSize(imageWidth, imageHeight);

    final depthMap = await _engine.run(frame);
    _logDepthStats(depthMap);
    final scaleSamples = <ScaleSample>[];

    _collectGroundSamples(
      samples: scaleSamples,
      depthMap: depthMap,
      objects: objects,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );

    _collectPriorSamples(
      samples: scaleSamples,
      depthMap: depthMap,
      objects: objects,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );

    debugPrint('[MiDaS] Scale samples: ${scaleSamples.length}');

    if (_scaleEma != null) {
      scaleSamples.add(ScaleSample(scale: _scaleEma!, weight: 0.5));
      debugPrint('[MiDaS] Using EMA scale prior: ${_scaleEma!.toStringAsFixed(4)}');
    }

    final fused = _fuser.fuse(scaleSamples);
    final scale = fused.scale;
    debugPrint('[MiDaS] Fused scale: ${scale?.toStringAsFixed(4) ?? 'null'} | confidence=${fused.confidence.toStringAsFixed(3)}');
    if (scale == null || scale <= 0) {
      debugPrint('[MiDaS] No valid scale. Returning -1 distances.');
      return objects.map((o) => o.copyWithDistance(distanceCm: -1)).toList();
    }

    _scaleEma = _scaleEma == null
        ? scale
        : _scaleEma! * (1 - _emaAlpha) + scale * _emaAlpha;

    final updated = <DetectedObject>[];
    for (final object in objects) {
      final relDepth = _sampleObjectDepth(
        depthMap: depthMap,
        object: object,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );

      if (relDepth == null || relDepth <= _minRelDepth) {
        debugPrint('[MiDaS] Invalid depth for ${object.label}.');
        updated.add(object.copyWithDistance(distanceCm: -1));
        continue;
      }

      final distanceMeters = (scale / relDepth).clamp(_minDistanceM, _maxDistanceM);
      debugPrint('[MiDaS] ${object.label}: rel=$relDepth -> ${distanceMeters.toStringAsFixed(2)}m');
      updated.add(
        object.copyWithDistance(distanceCm: (distanceMeters * 100).round()),
      );
    }

    return updated;
  }

  void _collectGroundSamples({
    required List<ScaleSample> samples,
    required DepthMap depthMap,
    required List<DetectedObject> objects,
    required int imageWidth,
    required int imageHeight,
  }) {
    var added = 0;
    var candidates = 0;
    var skippedInside = 0;
    var skippedIntersect = 0;
    var skippedConfidence = 0;
    var skippedRelDepth = 0;
    final startY = (imageHeight * _groundStartRatio).round();
    for (var y = startY; y < imageHeight; y += _groundStridePx) {
      for (var x = 0; x < imageWidth; x += _groundStridePx) {
        candidates++;
        if (_isInsideAnyBox(x, y, objects)) {
          skippedInside++;
          continue;
        }

        final footPoint = FootPoint(u: x.toDouble(), v: y.toDouble());
        final intersection = _intersectionEngine.intersect(
          footPoint: footPoint,
          intrinsics: _intrinsics,
          extrinsics: _extrinsics,
        );

        if (intersection.distance3d == null) {
          skippedIntersect++;
          continue;
        }
        final confidence = _confidenceEstimator.estimate(
          intersection: intersection,
          footPoint: footPoint,
          intrinsics: _intrinsics,
          extrinsics: _extrinsics,
        );
        if (confidence.confidence <= 0.2) {
          skippedConfidence++;
          continue;
        }

        final relDepth = _sampleDepth(
          depthMap: depthMap,
          x: x.toDouble(),
          y: y.toDouble(),
          imageWidth: imageWidth,
          imageHeight: imageHeight,
        );
        if (relDepth == null || relDepth <= _minRelDepth) {
          skippedRelDepth++;
          continue;
        }

        samples.add(
          ScaleSample(
            scale: intersection.distance3d! * relDepth,
            weight: confidence.confidence,
          ),
        );
        added++;
      }
    }
    debugPrint(
      '[MiDaS] Ground samples added: $added (candidates=$candidates, inside=$skippedInside, noIntersect=$skippedIntersect, lowConf=$skippedConfidence, badRel=$skippedRelDepth)',
    );
  }

  void _collectPriorSamples({
    required List<ScaleSample> samples,
    required DepthMap depthMap,
    required List<DetectedObject> objects,
    required int imageWidth,
    required int imageHeight,
  }) {
    var added = 0;
    final pinholeObjects = _pinholeEstimator.estimateForObjects(
      objects: objects,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      frame: null,
    );

    for (var i = 0; i < pinholeObjects.length; i++) {
      final pinhole = pinholeObjects[i];
      if (pinhole.distanceCm <= 0) {
        debugPrint('[MiDaS] Pinhole distance invalid for ${pinhole.label}.');
        continue;
      }
      final relDepth = _sampleObjectDepth(
        depthMap: depthMap,
        object: pinhole,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );
      if (relDepth == null || relDepth <= _minRelDepth) {
        debugPrint('[MiDaS] Prior sample depth invalid for ${pinhole.label}.');
        continue;
      }

      final prior = _priorDatabase.getPrior(pinhole.label);
      final weight = math.max(0.1, pinhole.confidence * prior.heightConfidence);
      debugPrint(
        '[MiDaS] Prior sample ${pinhole.label}: pinhole=${pinhole.distanceCm}cm rel=$relDepth weight=${weight.toStringAsFixed(2)}',
      );
      samples.add(
        ScaleSample(
          scale: (pinhole.distanceCm / 100.0) * relDepth,
          weight: weight,
        ),
      );
      added++;
    }
    debugPrint('[MiDaS] Prior samples added: $added');
  }

  void _logDepthStats(DepthMap depthMap) {
    var minValue = double.infinity;
    var maxValue = -double.infinity;
    var zeroLike = 0;
    for (final value in depthMap.data) {
      if (value < minValue) minValue = value;
      if (value > maxValue) maxValue = value;
      if (value <= _minRelDepth) zeroLike++;
    }
    debugPrint(
      '[MiDaS] Depth stats: min=$minValue max=$maxValue zeros=$zeroLike/${depthMap.data.length}',
    );
  }

  double? _sampleObjectDepth({
    required DepthMap depthMap,
    required DetectedObject object,
    required int imageWidth,
    required int imageHeight,
  }) {
    final x1 = object.bbox['x1'] ?? 0;
    final y1 = object.bbox['y1'] ?? 0;
    final x2 = object.bbox['x2'] ?? 0;
    final y2 = object.bbox['y2'] ?? 0;
    if (x2 <= x1 || y2 <= y1) return null;

    final samples = <double>[];
    const grid = 6;
    final stepX = (x2 - x1) / (grid + 1);
    final stepY = (y2 - y1) / (grid + 1);

    for (var gy = 1; gy <= grid; gy++) {
      for (var gx = 1; gx <= grid; gx++) {
        final x = x1 + gx * stepX;
        final y = y1 + gy * stepY;
        final relDepth = _sampleDepth(
          depthMap: depthMap,
          x: x,
          y: y,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
        );
        if (relDepth != null && relDepth > _minRelDepth) {
          samples.add(relDepth);
        }
      }
    }

    if (samples.isEmpty) return null;
    samples.sort();
    final filtered = _iqrFilter(samples);
    if (filtered.isEmpty) return samples[samples.length ~/ 2];

    final q25 = _quantile(filtered, 0.25);
    return q25;
  }

  double? _sampleDepth({
    required DepthMap depthMap,
    required double x,
    required double y,
    required int imageWidth,
    required int imageHeight,
  }) {
    final scaleX = depthMap.width / imageWidth;
    final scaleY = depthMap.height / imageHeight;
    final dx = (x * scaleX).round().clamp(0, depthMap.width - 1);
    final dy = (y * scaleY).round().clamp(0, depthMap.height - 1);
    return depthMap.valueAt(dx, dy);
  }

  bool _isInsideAnyBox(int x, int y, List<DetectedObject> objects) {
    for (final object in objects) {
      final x1 = object.bbox['x1'] ?? 0;
      final y1 = object.bbox['y1'] ?? 0;
      final x2 = object.bbox['x2'] ?? 0;
      final y2 = object.bbox['y2'] ?? 0;
      if (x >= x1 && x <= x2 && y >= y1 && y <= y2) return true;
    }
    return false;
  }

  List<double> _iqrFilter(List<double> values) {
    if (values.length < 4) return values.toList();
    final q1 = _quantile(values, 0.25);
    final q3 = _quantile(values, 0.75);
    final iqr = q3 - q1;
    final lower = q1 - 1.5 * iqr;
    final upper = q3 + 1.5 * iqr;
    return values.where((v) => v >= lower && v <= upper).toList();
  }

  double _quantile(List<double> sorted, double q) {
    if (sorted.isEmpty) return 0.0;
    final pos = (sorted.length - 1) * q;
    final lower = pos.floor();
    final upper = pos.ceil();
    if (lower == upper) return sorted[lower];
    final weight = pos - lower;
    return sorted[lower] * (1 - weight) + sorted[upper] * weight;
  }
}
