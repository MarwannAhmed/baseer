import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../domain/text_extractor_interface.dart';

class RemoteTextExtractor implements TextExtractorInterface {
  final String baseUrl;
  final String command;

  RemoteTextExtractor({required this.baseUrl, this.command = 'نص'});

  @override
  Future<void> init() async {}

  @override
  Future<String> extract(img.Image image) async {
    final List<int> jpegBytes = img.encodeJpg(image, quality: 85);

    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze'))
      ..fields['command'] = command
      ..files.add(
        http.MultipartFile.fromBytes('file', jpegBytes, filename: 'image.jpg'),
      );

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) return '';

    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json.containsKey('error')) {
      return '';
    }
    final description = json['description'];
    if (description is Map) return description['text'] as String? ?? '';
    return description as String? ?? '';
  }

  @override
  void dispose() {}
}
