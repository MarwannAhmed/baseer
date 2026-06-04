import 'dart:math' as math;

class CameraExtrinsicsManager {
  double heightMeters;
  double pitchDeg;
  double rollDeg;

  CameraExtrinsicsManager({
    required this.heightMeters,
    required this.pitchDeg,
    this.rollDeg = 0.0,
  });

  double get pitchRad => pitchDeg * math.pi / 180.0;
  double get rollRad => rollDeg * math.pi / 180.0;
}
