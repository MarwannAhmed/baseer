// lib/features/camera/data/analysis_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:baseer/core/api_constants.dart';
import 'package:baseer/features/analysis/domain/analysis_result.dart';

/// Sends a captured image and a voice command to the FastAPI backend
/// and returns a structured [AnalysisResult].
///
/// Fix vs original: import paths now use package-level imports instead of
/// relative paths that were pointing to non-existent folder locations.
class AnalysisService {
  /// [imagePath] – file-system path obtained from [CameraService.takePicture]
  /// [command]   – raw Arabic/English command string from STT
  ///
  /// Throws [AnalysisException] on non-200 responses or network errors.
  Future<AnalysisResult> analyze({
    required String imagePath,
    required String command,
  }) async {
    final request = http.MultipartRequest('POST', ApiConstants.analyzeUri)
      ..fields['command'] = command
      ..files.add(await http.MultipartFile.fromPath('file', imagePath));

    final streamedResponse =
        await request.send().timeout(ApiConstants.requestTimeout);

    if (streamedResponse.statusCode != 200) {
      throw AnalysisException(
        'Backend returned ${streamedResponse.statusCode}',
      );
    }

    final body = await streamedResponse.stream.bytesToString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    return AnalysisResult.fromJson(json);
  }
}

class AnalysisException implements Exception {
  final String message;
  const AnalysisException(this.message);

  @override
  String toString() => 'AnalysisException: $message';
}