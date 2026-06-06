import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../domain/detection_result.dart';
import '../domain/object_detector.dart';

class RemoteObjectDetector implements ObjectDetector {
  final String baseUrl;
  final http.Client _client;

  RemoteObjectDetector({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<void> init() async {}

  @override
  Future<List<DetectionResult>> detect(img.Image image) async {
    final List<int> jpegBytes = img.encodeJpg(image, quality: 85);
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze'))
      ..fields['command'] = 'كشف'
      ..files.add(
        http.MultipartFile.fromBytes('file', jpegBytes, filename: 'image.jpg'),
      );
    final streamedResponse = await _client.send(request).timeout(
      const Duration(seconds: 30),
    );
    if (streamedResponse.statusCode != 200) {
      return [];
    }
    final body = await streamedResponse.stream.bytesToString();
    final Map<String, dynamic> json = jsonDecode(body);
    final List<dynamic> objects = json['objects'] as List<dynamic>? ?? [];
    return objects.map((object) {
      final bbox = object['bbox'] as Map<String, dynamic>;
      return DetectionResult(
        label: object['label'] as String,
        confidence: (object['confidence'] as num).toDouble(),
        boundingBox: BoundingBox(
          x1: (bbox['x1'] as num).toDouble(),
          y1: (bbox['y1'] as num).toDouble(),
          x2: (bbox['x2'] as num).toDouble(),
          y2: (bbox['y2'] as num).toDouble(),
        ),
      );
    }).toList();
  }

  @override
  void dispose() {}
}
