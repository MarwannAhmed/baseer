import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:baseer/features/object_detection/application/remote_object_detector.dart';

void main() {
  group('RemoteObjectDetector', () {
    final image = img.Image(width: 100, height: 100);

    test('200 response returns correct DetectionResult list', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'objects': [
                {
                  'label': 'person',
                  'confidence': 0.95,
                  'bbox': {'x1': 10.0, 'y1': 20.0, 'x2': 100.0, 'y2': 200.0},
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          ));
      final detector = RemoteObjectDetector(baseUrl: 'http://test', client: client);
      final results = await detector.detect(image);
      expect(results.length, equals(1));
      expect(results.first.label, equals('person'));
      expect(results.first.confidence, closeTo(0.95, 0.001));
      expect(results.first.boundingBox.x1, closeTo(10.0, 0.001));
    });

    test('200 response with empty objects returns empty list', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'objects': []}),
            200,
            headers: {'content-type': 'application/json'},
          ));
      final detector = RemoteObjectDetector(baseUrl: 'http://test', client: client);
      final results = await detector.detect(image);
      expect(results, isEmpty);
    });

    test('non-200 response returns empty list without throwing', () async {
      final client = MockClient((_) async => http.Response('error', 503));
      final detector = RemoteObjectDetector(baseUrl: 'http://test', client: client);
      final results = await detector.detect(image);
      expect(results, isEmpty);
    });

    test('sends POST to <baseUrl>/analyze', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode({'objects': []}), 200,
            headers: {'content-type': 'application/json'});
      });
      final detector = RemoteObjectDetector(baseUrl: 'http://myserver:8080', client: client);
      await detector.detect(image);
      expect(capturedUri.toString(), contains('myserver:8080'));
      expect(capturedUri!.path, equals('/analyze'));
    });

    test('init() completes without error', () async {
      final detector = RemoteObjectDetector(baseUrl: 'http://test');
      await expectLater(detector.init(), completes);
    });

    test('dispose() runs without error', () {
      final detector = RemoteObjectDetector(baseUrl: 'http://test');
      expect(() => detector.dispose(), returnsNormally);
    });
  });
}
