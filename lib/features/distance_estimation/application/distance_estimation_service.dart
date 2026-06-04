import 'package:baseer/features/analysis/domain/detected_object.dart';
import 'package:baseer/features/distance_estimation/application/distance_method_config.dart';
import 'package:baseer/features/distance_estimation/application/method1/pinhole_prior_distance_estimator.dart';

class DistanceEstimationService {
  final DistanceMethod _method;
  final double _fovHorizontalDeg;
  PinholePriorDistanceEstimator? _method1;

  DistanceEstimationService._({
    required DistanceMethod method,
    required double fovHorizontalDeg,
  })  : _method = method,
        _fovHorizontalDeg = fovHorizontalDeg;

  factory DistanceEstimationService.fromEnv() {
    return DistanceEstimationService._(
      method: DistanceMethodConfig.readMethod(),
      fovHorizontalDeg: DistanceMethodConfig.readFovHorizontalDeg(),
    );
  }

  List<DetectedObject> estimateForObjects({
    required List<DetectedObject> objects,
    required int imageWidth,
    required int imageHeight,
    required dynamic frame,
  }) {
    if (objects.isEmpty) return objects;

    if (_method != DistanceMethod.method1) {
      return objects
          .map((o) => o.copyWithDistance(distanceCm: -1))
          .toList();
    }

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
}
