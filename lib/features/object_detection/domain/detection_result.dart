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
  double get cx => (x1 + x2) / 2;
  double get cy => (y1 + y2) / 2;

  @override
  String toString() =>
      'Bounding Box Coordinates: (Top-Left X:${x1.toStringAsFixed(1)}, Top-Left Y:${y1.toStringAsFixed(1)}, '
      'Bottom-Right X:${x2.toStringAsFixed(1)}, Bottom-Right Y:${y2.toStringAsFixed(1)})';
}

class DetectionResult {
  final String className;
  final double confidenceScore;
  final BoundingBox boundingBox;

  const DetectionResult({
    required this.className,
    required this.confidenceScore,
    required this.boundingBox,
  });

  @override
  String toString() =>
      'Detection($className @ ${(confidenceScore * 100).round()}%, with $boundingBox)';
}
