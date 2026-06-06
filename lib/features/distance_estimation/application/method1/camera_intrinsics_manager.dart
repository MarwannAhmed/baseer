import 'dart:math' as math;

class CameraIntrinsicsManager {

  final double fovH;
  int width;
  int height;
  double? calibratedFocalL;

  CameraIntrinsicsManager({
    required this.width,
    required this.height,
  })  : fovH = 69.0;

  static double d2r(double deg) => deg * math.pi / 180.0;
  static double r2d(double rad) => rad * 180.0 / math.pi;

  void updateImageSize(int width, int height) {
    this.width = width;
    this.height = height;
  }

  double get fPx {
    final fovH = d2r(this.fovH);
    return (width / 2) / math.tan(fovH / 2);
  }

  double get fPy {
    if (calibratedFocalL != null && calibratedFocalL! > 0) {
      return calibratedFocalL!;
    }
    final fovH = d2r(this.fovH);
    final aspect = height / width;
    final fovV = 2 * math.atan(math.tan(fovH / 2) * aspect);
    return (height / 2) / math.tan(fovV / 2);
  }

  void calibrateFocalL(double value, {double alpha = 0.05}) {
    if (value <= 0) return;
    if (calibratedFocalL == null) {
      calibratedFocalL = value;
      return;
    }
    calibratedFocalL = alpha * value + (1 - alpha) * calibratedFocalL!;
  }

}