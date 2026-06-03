/// A single object returned by the FastAPI `/analyze` endpoint.
/// colorEn and colorAr are filled in on-device by the colour pipeline
/// after the backend returns bbox coordinates.
class DetectedObject {
  final String label;
  final double confidence;
  final Map<String, int> bbox;   // {x1, y1, x2, y2}
  final Map<String, int> center; // {x, y}
  final Map<String, int> size;   // {width, height}
  String colorEn;
  String colorAr;
  final int distanceCm;

  DetectedObject({
    required this.label,
    required this.confidence,
    required this.bbox,
    required this.center,
    required this.size,
    this.colorEn = '',
    this.colorAr = '',
    required this.distanceCm,
  });

  factory DetectedObject.fromJson(Map<String, dynamic> json) {
    return DetectedObject(
      label:      json['label'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      bbox:       _intMap(json['bbox']),
      center:     _intMap(json['center']),
      size:       _intMap(json['size']),
      distanceCm: (json['distance_cm'] as num?)?.toInt() ?? 0,
    );
  }

  static Map<String, int> _intMap(dynamic raw) {
    if (raw == null) return {};
    return (raw as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, (v as num).toInt()));
  }
}