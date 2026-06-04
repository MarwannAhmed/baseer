import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../domain/detection_result.dart';
import '../domain/object_detector.dart';

import 'package:flutter/foundation.dart';

class RemoteObjectDetector implements ObjectDetector {
  final String baseUrl;

  RemoteObjectDetector({required this.baseUrl});

  @override
  Future<void> init() async {}

  @override
  Future<List<DetectionResult>> detect(img.Image image) async {
    debugPrint('🟡 RemoteDetector: encoding image');
    final List<int> jpegBytes = img.encodeJpg(image, quality: 85);
    debugPrint('🟡 RemoteDetector: image size ${jpegBytes.length} bytes');

    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze'))
      ..fields['command'] = 'كشف'
      ..files.add(
        http.MultipartFile.fromBytes('file', jpegBytes, filename: 'image.jpg'),
      );

    debugPrint('🟡 RemoteDetector: sending to $baseUrl/analyze');

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 30),
    );

    debugPrint('🟡 RemoteDetector: got status ${streamedResponse.statusCode}');

    if (streamedResponse.statusCode != 200) {
      debugPrint('🔴 RemoteDetector: non-200 response');
      return [];
    }

    final body = await streamedResponse.stream.bytesToString();
    debugPrint('🟡 RemoteDetector: raw response: $body');

    final Map<String, dynamic> json = jsonDecode(body);
    final List<dynamic> objects = json['objects'] as List<dynamic>? ?? [];
    debugPrint('🟢 RemoteDetector: parsed ${objects.length} objects');

    return objects.map((o) {
      final bbox = o['bbox'] as Map<String, dynamic>;
      return DetectionResult(
        label: o['label'] as String,
        confidence: (o['confidence'] as num).toDouble(),
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
  void dispose() {} // nothing to release for a remote call
}
