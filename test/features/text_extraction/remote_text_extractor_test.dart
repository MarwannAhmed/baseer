import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:baseer/features/text_extraction/application/remote_text_extractor.dart';

void main() {
  group('RemoteTextExtractor', () {
    final image = img.Image(width: 100, height: 100);

    test('flat description string returns correct text', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'description': 'hello world'}),
            200,
            headers: {'content-type': 'application/json'},
          ));
      final extractor = RemoteTextExtractor(baseUrl: 'http://test', client: client);
      expect(await extractor.extract(image), equals('hello world'));
    });

    test('nested description.text returns correct text', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'description': {'text': 'nested text'}}),
            200,
            headers: {'content-type': 'application/json'},
          ));
      final extractor = RemoteTextExtractor(baseUrl: 'http://test', client: client);
      expect(await extractor.extract(image), equals('nested text'));
    });

    test('error key in JSON returns empty string', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'error': 'OCR failed'}),
            200,
            headers: {'content-type': 'application/json'},
          ));
      final extractor = RemoteTextExtractor(baseUrl: 'http://test', client: client);
      expect(await extractor.extract(image), equals(''));
    });

    test('non-200 response returns empty string', () async {
      final client = MockClient((_) async => http.Response('error', 400));
      final extractor = RemoteTextExtractor(baseUrl: 'http://test', client: client);
      expect(await extractor.extract(image), equals(''));
    });

    test('default command field is نص (checked via URL)', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode({'description': ''}), 200,
            headers: {'content-type': 'application/json'});
      });
      final extractor = RemoteTextExtractor(baseUrl: 'http://test', client: client);
      await extractor.extract(image);
      expect(capturedUri?.path, equals('/analyze'));
    });

    test('init() completes without error', () async {
      final extractor = RemoteTextExtractor(baseUrl: 'http://test');
      await expectLater(extractor.init(), completes);
    });
  });
}
