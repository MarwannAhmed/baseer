import 'detected_object.dart';

/// The full response from the FastAPI `/analyze` endpoint.
class AnalysisResult {
  /// Human/TTS-ready description (Arabic or English depending on command).
  final String description;

  /// Individual detected objects with color and distance.
  final List<DetectedObject> objects;

  const AnalysisResult({
    required this.description,
    required this.objects,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawObjects = json['objects'] as List<dynamic>? ?? [];
    return AnalysisResult(
      description: json['description'] as String? ?? '',
      objects: rawObjects
          .map((o) => DetectedObject.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Convenience: returns [description] directly so callers can pass this
  /// to TTS without extra dereferencing.
  @override
  String toString() => description;
}