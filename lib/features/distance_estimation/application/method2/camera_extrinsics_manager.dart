import 'dart:math' as math;

class CameraExtrinsicsManager {

  double hCam;
  double pitch;

  CameraExtrinsicsManager()
    : hCam = 1.20,
      pitch = 15;

  double get pitchRad => pitch * math.pi / 180.0;

}