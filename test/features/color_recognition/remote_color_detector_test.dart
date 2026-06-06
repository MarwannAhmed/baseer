import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:baseer/features/color_recognition/application/remote_color_detector.dart';

void main() {
  group('RemoteColorDetector', () {
    final image = img.Image(width: 100, height: 100);

    test('200 response with red color returns correct result', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'color': {'color': 'red'}}),
            200,
            headers: {'content-type': 'application/json'},
          ));
      final detector = RemoteColorDetector(baseUrl: 'http://test', client: client);
      final result = await detector.detect(image);
      expect(result.colorEn, equals('red'));
      expect(result.colorAr, equals('أحمر'));
    });

    test('200 response with green color maps to Arabic', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'color': {'color': 'green'}}),
            200,
            headers: {'content-type': 'application/json'},
          ));
      final detector = RemoteColorDetector(baseUrl: 'http://test', client: client);
      final result = await detector.detect(image);
      expect(result.colorEn, equals('green'));
      expect(result.colorAr, equals('أخضر'));
    });

    test('unknown color falls back to colorEn as colorAr', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'color': {'color': 'magenta'}}),
            200,
            headers: {'content-type': 'application/json'},
          ));
      final detector = RemoteColorDetector(baseUrl: 'http://test', client: client);
      final result = await detector.detect(image);
      expect(result.colorEn, equals('magenta'));
      expect(result.colorAr, equals('magenta')); // falls back to en value
    });

    test('non-200 response returns unknown result', () async {
      final client = MockClient((_) async => http.Response('error', 503));
      final detector = RemoteColorDetector(baseUrl: 'http://test', client: client);
      final result = await detector.detect(image);
      expect(result.colorEn, equals('unknown'));
      expect(result.colorAr, equals('غير معروف'));
    });

    test('missing color key returns unknown', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'other': 'data'}),
            200,
            headers: {'content-type': 'application/json'},
          ));
      final detector = RemoteColorDetector(baseUrl: 'http://test', client: client);
      final result = await detector.detect(image);
      expect(result.colorEn, equals('unknown'));
    });
  });
}
