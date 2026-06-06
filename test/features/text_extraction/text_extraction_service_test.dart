import 'package:flutter_test/flutter_test.dart';
import 'package:baseer/features/text_extraction/application/text_extraction_service.dart';

void main() {
  group('TextExtractionService factories', () {
    test('remote() constructs without error', () {
      expect(() => TextExtractionService.remote(baseUrl: 'http://test'), returnsNormally);
    });

    test('remoteOcr() constructs without error', () {
      expect(() => TextExtractionService.remoteOcr(baseUrl: 'http://test'), returnsNormally);
    });

    test('remoteOcrAr() constructs without error', () {
      expect(() => TextExtractionService.remoteOcrAr(baseUrl: 'http://test'), returnsNormally);
    });
  });

  group('TextExtractionService lifecycle', () {
    test('init() completes without error for remote', () async {
      final service = TextExtractionService.remote(baseUrl: 'http://test');
      await expectLater(service.init(), completes);
    });

    test('dispose() runs without error', () {
      final service = TextExtractionService.remote(baseUrl: 'http://test');
      expect(() => service.dispose(), returnsNormally);
    });
  });
}
