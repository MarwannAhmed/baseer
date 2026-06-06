import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:baseer/features/analysis/domain/detected_object.dart';
import 'package:baseer/features/distance_estimation/application/method1/pinhole_prior_distance_estimator.dart';
import 'package:baseer/features/distance_estimation/application/method2/ground_plane_projection_estimator.dart';
import 'package:baseer/features/distance_estimation/application/method3/midas_depth_distance_estimator.dart';

class DistanceEstimationService {

  final int method;
  PinholePriorDistanceEstimator? method1;
  GroundPlaneProjectionEstimator? method2;
  MidasDepthDistanceEstimator? method3;

  DistanceEstimationService(): method = _readMethod();

  static int _readMethod() {
    final raw = dotenv.env['DISTANCE']?.trim();
    final value = int.tryParse(raw ?? '');
    if (value != null && (value == 1 || value == 2 || value == 3)) {
      return value;
    }
    return 1;
  }

  Future<List<DetectedObject>> estimateForObjects({
    required List<DetectedObject> objects,
    required int width,
    required int height,
    required dynamic frame,
  }) async {
    if (objects.isEmpty) return objects;
    if (method == 1) {
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
    if (method == 2) {
      method2 ??= GroundPlaneProjectionEstimator(
        width: width,
        height: height,
      );
      return method2!.estimateForObjects(
        objects: objects,
        width: width,
        height: height,
        frame: frame,
      );
    }
    method3 ??= MidasDepthDistanceEstimator(
      width: width,
      height: height,
    );
    return method3!.estimateForObjects(
      objects: objects,
      width: width,
      height: height,
      frame: frame,
    );
  }

}
