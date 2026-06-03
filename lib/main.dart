import 'package:baseer/app/baseer_app.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:baseer/features/color_recognition/application/color_detector_factory.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  ColorDetectorFactory.mode = ColorDetectorMode.svm;
  
  runApp(const BaseerApp());
}
