import 'package:image/image.dart' as img;

import '../domain/text_extractor_interface.dart';
import 'remote_text_extractor.dart';

class TextExtractionService {
  final TextExtractorInterface _extractor;

  TextExtractionService._(this._extractor);

  factory TextExtractionService.remote({required String baseUrl}) {
    return TextExtractionService._(RemoteTextExtractor(baseUrl: baseUrl));
  }

  Future<void> init() => _extractor.init();
  Future<String> extractText(img.Image image) => _extractor.extract(image);
  void dispose() => _extractor.dispose();
}
