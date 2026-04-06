import 'package:camera/camera.dart';

class CameraInitializer {
  const CameraInitializer();

  Future<List<CameraDescription>> getAvailableCameras() {
    return availableCameras();
  }

  CameraController createController(CameraDescription camera) {
    return CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
  }
}
