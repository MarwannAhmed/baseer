import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:baseer/features/text_extraction/application/remote_text_extractor.dart';

void main() {
  group('Text extraction pipeline (remote)', () {
    final image = img.Image(width: 100, height: 100);

    test('flat description string is returned as-is', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'description': 'Hello World'}),
            200,
            headers: {'content-type': 'application/json'},
          ));
      final extractor = RemoteTextExtractor(
        baseUrl: 'http://test',
        command: 'نص',
        client: client,
      );
      final result = await extractor.extract(image);
      expect(result, equals('Hello World'));
    });

    test('nested description.text is unwrapped correctly', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'description': {'text': 'مرحبا بالعالم'}}),
            200,
            headers: {'content-type': 'application/json'},
          ));
      final extractor = RemoteTextExtractor(
        baseUrl: 'http://test',
        command: 'نصا',
        client: client,
      );
      final result = await extractor.extract(image);
      expect(result, equals('مرحبا بالعالم'));
    });

    test('error response returns empty string', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'error': 'OCR model not loaded'}),
            200,
            headers: {'content-type': 'application/json'},
          ));
      final extractor = RemoteTextExtractor(baseUrl: 'http://test', client: client);
      final result = await extractor.extract(image);
      expect(result, equals(''));
    });

    test('non-200 HTTP response returns empty string', () async {
      final client = MockClient((_) async => http.Response('server error', 500));
      final extractor = RemoteTextExtractor(baseUrl: 'http://test', client: client);
      final result = await extractor.extract(image);
      expect(result, equals(''));
    });

    test('empty description string returns empty string', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'description': ''}),
            200,
            headers: {'content-type': 'application/json'},
          ));
      final extractor = RemoteTextExtractor(baseUrl: 'http://test', client: client);
      final result = await extractor.extract(image);
      expect(result, equals(''));
    });
  });
}
