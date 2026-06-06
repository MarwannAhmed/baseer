class DistanceEstimate {

  final double? dist;
  final double? std;
  final double confidence;
  final String? error;

  const DistanceEstimate({
    required this.dist,
    required this.std,
    required this.confidence,
    this.error,
  });

}