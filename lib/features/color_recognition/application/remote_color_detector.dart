import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'color_detector_factory.dart';

const Map<String, String> _colorArabic = {
  'red':    'أحمر',
  'green':  'أخضر',
  'blue':   'أزرق',
  'yellow': 'أصفر',
  'orange': 'برتقالي',
  'brown':  'بني',
  'purple': 'بنفسجي',
  'pink':   'وردي',
  'white':  'أبيض',
  'gray':   'رمادي',
  'black':  'أسود',
};

class RemoteColorDetector {
  final String baseUrl;
  final http.Client _client;

  RemoteColorDetector({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  Future<UnifiedColorResult> detect(img.Image image) async {
    final List<int> jpegBytes = img.encodeJpg(image, quality: 85);

    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze'))
      ..fields['command'] = 'لون'
      ..files.add(
        http.MultipartFile.fromBytes('file', jpegBytes, filename: 'image.jpg'),
      );

    debugPrint('🟡 RemoteColorDetector: sending to $baseUrl/analyze');

    final streamed = await _client.send(request).timeout(const Duration(seconds: 30));
    final body = await streamed.stream.bytesToString();

    debugPrint('🟡 RemoteColorDetector: status ${streamed.statusCode}: $body');

    if (streamed.statusCode != 200) {
      return const UnifiedColorResult(colorEn: 'unknown', colorAr: 'غير معروف');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final colorObj = json['color'] as Map<String, dynamic>?;
    final colorEn = colorObj?['color'] as String? ?? 'unknown';
    final colorAr = _colorArabic[colorEn] ?? colorEn;

    return UnifiedColorResult(colorEn: colorEn, colorAr: colorAr);
  }
}
