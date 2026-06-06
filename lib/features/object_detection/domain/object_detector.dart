import 'package:image/image.dart' as img;
import 'detection_result.dart';

abstract class ObjectDetector {
  Future<void> init();

  Future<List<DetectionResult>> detect(img.Image image);

  void dispose();
}