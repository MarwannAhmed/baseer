import 'dart:math' as math;

class ScaleSample {
  final double scale;
  final double weight;

  const ScaleSample({required this.scale, required this.weight});
}

class WeightedMedianResult {
  final double? scale;
  final double confidence;

  const WeightedMedianResult({required this.scale, required this.confidence});
}

class WeightedMedianFuser {
  const WeightedMedianFuser();

  WeightedMedianResult fuse(List<ScaleSample> samples) {
    if (samples.isEmpty) {
      return const WeightedMedianResult(scale: null, confidence: 0.0);
    }

    final sorted = samples.toList()..sort((a, b) => a.scale.compareTo(b.scale));
    final totalWeight = sorted.fold<double>(0.0, (sum, s) => sum + s.weight);
    if (totalWeight <= 0.0) {
      return const WeightedMedianResult(scale: null, confidence: 0.0);
    }

    var cumulative = 0.0;
    double? median;
    for (final sample in sorted) {
      cumulative += sample.weight;
      if (cumulative >= totalWeight * 0.5) {
        median = sample.scale;
        break;
      }
    }

    if (median == null) {
      return const WeightedMedianResult(scale: null, confidence: 0.0);
    }

    final q1 = _quantile(sorted, 0.25, totalWeight);
    final q3 = _quantile(sorted, 0.75, totalWeight);
    final spread = q1 != null && q3 != null && median > 0
        ? (q3 - q1) / median
        : 1.0;
    final confidence = math.exp(-spread.abs());

    return WeightedMedianResult(scale: median, confidence: confidence);
  }

  double? _quantile(
    List<ScaleSample> sorted,
    double q,
    double totalWeight,
  ) {
    var cumulative = 0.0;
    for (final sample in sorted) {
      cumulative += sample.weight;
      if (cumulative >= totalWeight * q) return sample.scale;
    }
    return sorted.isNotEmpty ? sorted.last.scale : null;
  }
}
