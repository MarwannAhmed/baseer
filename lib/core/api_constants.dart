import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class ApiConstants {
  static String get baseUri =>
      dotenv.env['BASE_URI']?.trim() ?? 'http://127.0.0.1:8000';

  static const String analyzeEndpoint = '/analyze';

  static Uri get analyzeUri => Uri.parse('$baseUri$analyzeEndpoint');

  static const Duration requestTimeout = Duration(seconds: 30);
}