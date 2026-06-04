import 'package:image/image.dart' as img;

import '../domain/text_extractor_interface.dart';
import 'text_extractor.dart';

class OnDeviceTextExtractor implements TextExtractorInterface {
  final String detModelPath;
  final String recModelPath;
  final String dictPath;

  OnDeviceTextExtractor({
    this.detModelPath = 'assets/models/det.onnx',
    this.recModelPath = 'assets/models/rec.onnx',
    this.dictPath     = 'assets/dict/ppocr_keys.txt',
  });

  @override
  Future<void> init() => TextExtractor.initialize(
        detModelPath: detModelPath,
        recModelPath: recModelPath,
        dictPath: dictPath,
      );

  @override
  Future<String> extract(img.Image image) => TextExtractor.extractText(image);

  @override
  void dispose() => TextExtractor.dispose();
}
