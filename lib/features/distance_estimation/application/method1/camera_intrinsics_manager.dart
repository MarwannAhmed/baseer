import 'dart:math' as math;

class CameraIntrinsicsManager {
  final double fovHorizontalDeg;
  int _imageWidth;
  int _imageHeight;
  double? _calibratedFocalPy;

  CameraIntrinsicsManager({
    required this.fovHorizontalDeg,
    required int imageWidth,
    required int imageHeight,
    double? calibratedFocalPy,
  })  : _imageWidth = imageWidth,
        _imageHeight = imageHeight,
        _calibratedFocalPy = calibratedFocalPy;

  int get imageWidth => _imageWidth;
  int get imageHeight => _imageHeight;

  void updateImageSize(int width, int height) {
    _imageWidth = width;
    _imageHeight = height;
  }

  double get fovVerticalDeg {
    final fovH = _degToRad(fovHorizontalDeg);
    final aspect = _imageHeight / _imageWidth;
    final fovV = 2 * math.atan(math.tan(fovH / 2) * aspect);
    return _radToDeg(fovV);
  }

  double get fPx {
    final fovH = _degToRad(fovHorizontalDeg);
    return (_imageWidth / 2) / math.tan(fovH / 2);
  }

  double get fPy {
    if (_calibratedFocalPy != null && _calibratedFocalPy! > 0) {
      return _calibratedFocalPy!;
    }
    final fovV = _degToRad(fovVerticalDeg);
    return (_imageHeight / 2) / math.tan(fovV / 2);
  }

  void updateCalibratedFocalPy(double value, {double alpha = 0.05}) {
    if (value <= 0) return;
    if (_calibratedFocalPy == null) {
      _calibratedFocalPy = value;
      return;
    }
    _calibratedFocalPy =
        alpha * value + (1 - alpha) * _calibratedFocalPy!;
  }

  static double _degToRad(double deg) => deg * math.pi / 180.0;
  static double _radToDeg(double rad) => rad * 180.0 / math.pi;
}
