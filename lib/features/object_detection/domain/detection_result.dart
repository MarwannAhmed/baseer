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

  double get width => x2 - x1;
  double get height => y2 - y1;

  double get centerX => (x1 + x2) / 2;
  double get centerY => (y1 + y2) / 2;
}

class DetectionResult {
  final String label;

  final double confidence;

  final BoundingBox boundingBox;

  const DetectionResult({
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });
}
