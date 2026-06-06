import 'package:image/image.dart' as img;

import '../domain/text_extractor_interface.dart';
import 'on_device_text_extractor.dart';
import 'remote_text_extractor.dart';

class TextExtractionService {
  final TextExtractorInterface _extractor;

  TextExtractionService._(this._extractor);

  factory TextExtractionService.onDevice({
    String detectionModelPath = 'assets/models/det.onnx',
    String recognitionModelPath = 'assets/models/rec.onnx',
    String dictionaryPath     = 'assets/dict/ppocr_keys.txt',
  }) {
    return TextExtractionService._(
      OnDeviceTextExtractor(
        detectionModelPath: detectionModelPath,
        recognitionModelPath: recognitionModelPath,
        dictionaryPath: dictionaryPath,
      ),
    );
  }

  factory TextExtractionService.remote({required String baseUrl}) {
    return TextExtractionService._(RemoteTextExtractor(baseUrl: baseUrl));
  }

  factory TextExtractionService.remoteOcr({required String baseUrl}) {
    return TextExtractionService._(RemoteTextExtractor(baseUrl: baseUrl, command: 'نصا'));
  }

  factory TextExtractionService.remoteOcrAr({required String baseUrl}) {
    return TextExtractionService._(RemoteTextExtractor(baseUrl: baseUrl, command: 'نصعر'));
  }

  Future<void> init() => _extractor.init();
  Future<String> extractText(img.Image image) => _extractor.extract(image);
  void dispose() => _extractor.dispose();
}
