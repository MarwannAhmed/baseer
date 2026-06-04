import 'package:baseer/features/analysis/domain/detected_object.dart';
import 'package:baseer/features/distance_estimation/application/distance_method_config.dart';
import 'package:baseer/features/distance_estimation/application/method1/pinhole_prior_distance_estimator.dart';
import 'package:baseer/features/distance_estimation/application/method2/ground_plane_projection_estimator.dart';
import 'package:baseer/features/distance_estimation/application/method3/midas_depth_distance_estimator.dart';

class DistanceEstimationService {
  final DistanceMethod _method;
  final double _fovHorizontalDeg;
  final double _cameraHeightMeters;
  final double _pitchDeg;
  PinholePriorDistanceEstimator? _method1;
  GroundPlaneProjectionEstimator? _method2;
  MidasDepthDistanceEstimator? _method3;

  DistanceEstimationService._({
    required DistanceMethod method,
    required double fovHorizontalDeg,
    required double cameraHeightMeters,
    required double pitchDeg,
  })  : _method = method,
        _fovHorizontalDeg = fovHorizontalDeg,
        _cameraHeightMeters = cameraHeightMeters,
        _pitchDeg = pitchDeg;

  factory DistanceEstimationService.fromEnv() {
    return DistanceEstimationService._(
      method: DistanceMethodConfig.readMethod(),
      fovHorizontalDeg: DistanceMethodConfig.readFovHorizontalDeg(),
      cameraHeightMeters: DistanceMethodConfig.readCameraHeightMeters(),
      pitchDeg: DistanceMethodConfig.readPitchDeg(),
    );
  }

  Future<List<DetectedObject>> estimateForObjects({
    required List<DetectedObject> objects,
    required int imageWidth,
    required int imageHeight,
    required dynamic frame,
  }) async {
    if (objects.isEmpty) return objects;

    if (_method == DistanceMethod.method1) {
      _method1 ??= PinholePriorDistanceEstimator(
        fovHorizontalDeg: _fovHorizontalDeg,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );

      return _method1!.estimateForObjects(
        objects: objects,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        frame: frame,
      );
    }

    if (_method == DistanceMethod.method2) {
      _method2 ??= GroundPlaneProjectionEstimator(
        fovHorizontalDeg: _fovHorizontalDeg,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        cameraHeightM: _cameraHeightMeters,
        pitchDeg: _pitchDeg,
      );

      return _method2!.estimateForObjects(
        objects: objects,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        frame: frame,
      );
    }

    _method3 ??= MidasDepthDistanceEstimator(
      modelAssetPath: DistanceMethodConfig.readMidasModelPath(),
      modelInputSize: DistanceMethodConfig.readMidasInputSize(),
      threads: DistanceMethodConfig.readMidasThreads(),
      fovHorizontalDeg: _fovHorizontalDeg,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      cameraHeightM: _cameraHeightMeters,
      pitchDeg: _pitchDeg,
      emaAlpha: DistanceMethodConfig.readMidasEmaAlpha(),
      groundStartRatio: DistanceMethodConfig.readMidasGroundStartRatio(),
      groundStridePx: DistanceMethodConfig.readMidasGroundStridePx(),
    );

    return _method3!.estimateForObjects(
      objects: objects,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      frame: frame,
    );
  }
}
