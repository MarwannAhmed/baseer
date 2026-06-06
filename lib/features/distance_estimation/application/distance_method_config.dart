

class DistanceMethodConfig {

  // static double readFovH() {
  //   final raw = dotenv.env['FOV_H']?.trim();
  //   final value = double.tryParse(raw ?? '');
  //   if (value != null && value > 0) return value;
  //   return 69.0;
  // }

  // static double readCamH() {
  //   final raw = dotenv.env['H_CAM']?.trim();
  //   final value = double.tryParse(raw ?? '');
  //   if (value != null && value > 0) return value;
  //   return 1.20;
  // }

  // static double readPitch() {
  //   final raw = dotenv.env['PITCH']?.trim();
  //   final value = double.tryParse(raw ?? '');
  //   if (value != null) return value;
  //   return 15.0;
  // }

  // static String readMidas() {
  //   final raw = dotenv.env['MIDAS_MODEL']?.trim();
  //   if (raw != null && raw.isNotEmpty) return raw;
  //   return 'assets/ml/midas.tflite';
  // }

  // static int readMidasInputSize() {
  //   final raw = dotenv.env['MIDAS_INPUT']?.trim();
  //   final value = int.tryParse(raw ?? '');
  //   if (value != null && value > 0) return value;
  //   return 256;
  // }

  // static int readMidasThreads() {
  //   final raw = dotenv.env['MIDAS_THREADS']?.trim();
  //   final value = int.tryParse(raw ?? '');
  //   if (value != null && value > 0) return value;
  //   return 2;
  // }

  // static double readMidasEmaAlpha() {
  //   final raw = dotenv.env['MIDAS_EMA']?.trim();
  //   final value = double.tryParse(raw ?? '');
  //   if (value != null && value > 0 && value <= 1.0) return value;
  //   return 0.30;
  // }

  // static double readMidasGroundStartRatio() {
  //   final raw = dotenv.env['MIDAS_GROUND_START']?.trim();
  //   final value = double.tryParse(raw ?? '');
  //   if (value != null && value > 0 && value < 1.0) return value;
  //   return 0.65;
  // }

  // static int readMidasGroundStridePx() {
  //   final raw = dotenv.env['MIDAS_GROUND_STRIDE']?.trim();
  //   final value = int.tryParse(raw ?? '');
  //   if (value != null && value > 0) return value;
  //   return 32;
  // }
}
