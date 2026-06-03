import 'package:image/image.dart' as image;
import 'detection_result.dart';

abstract class ObjectDetector {
  Future<void> init();
  Future<List<DetectionResult>> detect(image.Image image);
  void dispose();
}
