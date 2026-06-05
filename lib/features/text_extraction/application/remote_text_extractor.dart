import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../domain/text_extractor_interface.dart';

class RemoteTextExtractor implements TextExtractorInterface {
  final String baseUrl;

  RemoteTextExtractor({required this.baseUrl});

  @override
  Future<void> init() async {}

  @override
  Future<String> extract(img.Image image) async {
    final List<int> jpegBytes = img.encodeJpg(image, quality: 85);

    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze'))
      ..fields['command'] = 'نص'
      ..files.add(
        http.MultipartFile.fromBytes('file', jpegBytes, filename: 'image.jpg'),
      );

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) return '';

    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json.containsKey('error')) {
      return '';
    }
    return json['description'] as String? ?? '';
  }

  @override
  void dispose() {}
}
