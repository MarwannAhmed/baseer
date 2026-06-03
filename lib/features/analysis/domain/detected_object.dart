/// A single object returned by the FastAPI `/analyze` endpoint.
class DetectedObject {
  final String label;
  final double confidence;
  final Map<String, int> bbox; // {x1, y1, x2, y2}
  final Map<String, int> center; // {x, y}
  final Map<String, int> size; // {width, height}
  final String colorEn;
  final String colorAr;
  final int distanceCm;

  const DetectedObject({
    required this.label,
    required this.confidence,
    required this.bbox,
    required this.center,
    required this.size,
    required this.colorEn,
    required this.colorAr,
    required this.distanceCm,
  });

  factory DetectedObject.fromJson(Map<String, dynamic> json) {
    return DetectedObject(
      label: json['label'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      bbox: _intMap(json['bbox']),
      center: _intMap(json['center']),
      size: _intMap(json['size']),
      colorEn: json['color_en'] as String? ?? '',
      colorAr: json['color_ar'] as String? ?? '',
      distanceCm: (json['distance_cm'] as num?)?.toInt() ?? 0,
    );
  }

  factory DetectedObject.fromDetectionResult({
    required String label,
    required double confidence,
    required int x1,
    required int y1,
    required int x2,
    required int y2,
  }) {
    return DetectedObject(
      label: label,
      confidence: confidence,
      bbox: {'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2},
      center: {'x': ((x1 + x2) / 2).round(), 'y': ((y1 + y2) / 2).round()},
      size: {'width': x2 - x1, 'height': y2 - y1},
      colorEn: '',
      colorAr: '',
      distanceCm: 0,
    );
  }

  static Map<String, int> _intMap(dynamic raw) {
    if (raw == null) return {};
    return (raw as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    );
  }
}
