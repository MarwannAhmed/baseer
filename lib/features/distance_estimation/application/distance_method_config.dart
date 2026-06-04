import 'package:flutter_dotenv/flutter_dotenv.dart';

enum DistanceMethod { method1, method2, method3 }

class DistanceMethodConfig {
  static int readMethodIndex() {
    final raw = dotenv.env['DISTANCE']?.trim();
    final value = int.tryParse(raw ?? '') ?? 1;
    if (value == 1 || value == 2 || value == 3) return value;
    return 1;
  }

  static DistanceMethod readMethod() {
    final method = readMethodIndex();
    switch (method) {
      case 2:
        return DistanceMethod.method2;
      case 3:
        return DistanceMethod.method3;
      default:
        return DistanceMethod.method1;
    }
  }

  static double readFovHorizontalDeg() {
    final raw = dotenv.env['FOV_H']?.trim();
    final value = double.tryParse(raw ?? '');
    if (value != null && value > 0) return value;
    return 69.0;
  }

  static double readCameraHeightMeters() {
    final raw = dotenv.env['H_CAM']?.trim();
    final value = double.tryParse(raw ?? '');
    if (value != null && value > 0) return value;
    return 1.20;
  }

  static double readPitchDeg() {
    final raw = dotenv.env['PITCH_DEG']?.trim();
    final value = double.tryParse(raw ?? '');
    if (value != null) return value;
    return 15.0;
  }
}
