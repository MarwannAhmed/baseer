import 'package:image/image.dart' as img;

abstract class TextExtractorInterface {
  Future<void> init();
  Future<String> extract(img.Image image);
  void dispose();
}
