// lib/features/object_detection/domain/detection_result.dart
//
// Shared response model — identical whether results came from the on-device
// ONNX model or a remote backend.  Nothing outside this feature cares which
// approach was used.

/// Axis-aligned bounding box in original-image pixel coordinates.
/// x1/y1 = top-left corner, x2/y2 = bottom-right corner.
class BoundingBox {
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  const BoundingBox({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  double get width  => x2 - x1;
  double get height => y2 - y1;

  /// Centre point of the box.
  double get centerX => (x1 + x2) / 2;
  double get centerY => (y1 + y2) / 2;

  @override
  String toString() =>
      'BBox(x1:${x1.toStringAsFixed(1)}, y1:${y1.toStringAsFixed(1)}, '
      'x2:${x2.toStringAsFixed(1)}, y2:${y2.toStringAsFixed(1)})';
}

/// A single detected object — label, confidence, and where it is.
class DetectionResult {
  final String label;

  /// Confidence score in [0.0, 1.0].
  final double confidence;

  final BoundingBox boundingBox;

  const DetectionResult({
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });

  /// Convenience: confidence as a human-readable percentage string, e.g. "87%".
  String get confidencePercent => '${(confidence * 100).round()}%';

  @override
  String toString() =>
      'Detection($label @ $confidencePercent, $boundingBox)';
}