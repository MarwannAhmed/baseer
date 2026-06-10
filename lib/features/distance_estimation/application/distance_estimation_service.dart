import 'package:baseer/features/analysis/domain/detected_object.dart';
import 'package:baseer/features/distance_estimation/application/method1/pinhole_prior_distance_estimator.dart';

class DistanceEstimationService {

  PinholePriorDistanceEstimator? method1;

  Future<List<DetectedObject>> estimateForObjects({
    required List<DetectedObject> objects,
    required int width,
    required int height,
    required dynamic frame,
  }) async {
  if (objects.isEmpty) return objects;
    method1 ??= PinholePriorDistanceEstimator(
      width: width,
      height: height,
    );
    return method1!.estimateForObjects(
      objects: objects,
      width: width,
      height: height,
      frame: frame,
    );
  }

}
