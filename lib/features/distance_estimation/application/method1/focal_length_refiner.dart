import 'package:baseer/features/distance_estimation/application/method1/camera_intrinsics_manager.dart';
import 'package:baseer/features/distance_estimation/domain/object_size_prior.dart';

class FocalLengthRefiner {
  final List<double> _buffer = [];
  final int _bufferSize;

  FocalLengthRefiner({int bufferSize = 8}) : _bufferSize = bufferSize;

  void consider({
    required double detectionConfidence,
    required ObjectSizePrior prior,
    required double dist,
    required double heightPx,
    required bool isClipped,
    required CameraIntrinsicsManager intrinsics,
  }) {
    if (isClipped) return;
    if (detectionConfidence <= 0.85) return;
    if (prior.heightConfidence <= 0.80) return;
    if (heightPx <= 0) return;

    final implied = (dist * heightPx) / prior.typicalHeightM;
    if (implied <= 0) return;

    _buffer.add(implied);
    if (_buffer.length < _bufferSize) return;

    final median = _median(_buffer);
    intrinsics.updateCalibratedFocalPy(median);
    _buffer.clear();
  }

  double _median(List<double> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2.0;
  }
}
