class DistanceEstimate {
  final double? distanceMeters;
  final double? sigmaMeters;
  final double confidence;
  final String? error;

  const DistanceEstimate({
    required this.distanceMeters,
    required this.sigmaMeters,
    required this.confidence,
    this.error,
  });
}
