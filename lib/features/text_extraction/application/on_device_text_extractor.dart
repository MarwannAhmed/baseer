import 'package:image/image.dart' as img;
import '../domain/text_extractor_interface.dart';
import 'text_extractor.dart';

class OnDeviceTextExtractor implements TextExtractorInterface {
  final String detectionModelPath;
  final String recognitionModelPath;
  final String dictionaryPath;

  OnDeviceTextExtractor({
    this.detectionModelPath = 'assets/models/det.onnx',
    this.recognitionModelPath = 'assets/models/rec.onnx',
    this.dictionaryPath     = 'assets/dict/ppocr_keys.txt',
  });

  @override
  Future<void> init() => TextExtractor.initialize(
        detModelPath: detectionModelPath,
        recModelPath: recognitionModelPath,
        dictPath: dictionaryPath,
      );

  @override
  Future<String> extract(img.Image image) => TextExtractor.extractText(image);

  @override
  void dispose() => TextExtractor.dispose();
}
