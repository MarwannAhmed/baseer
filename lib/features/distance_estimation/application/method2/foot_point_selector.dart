class FootPoint {
  final double u;
  final double v;

  const FootPoint({required this.u, required this.v});
}

class FootPointSelector {
  const FootPointSelector();

  FootPoint select({
    required String label,
    required int x1,
    required int y1,
    required int x2,
    required int y2,
    required int imageHeight,
  }) {
    final u = (x1 + x2) / 2.0;
    final v = y2.toDouble();
    final beta = _footPointBeta[label] ?? 0.0;
    final corrected = (v + beta * (y2 - y1)).clamp(0.0, imageHeight - 1.0);
    return FootPoint(u: u, v: corrected);
  }
}

const Map<String, double> _footPointBeta = {
  'person': 0.05,
  'car': 0.02,
  'bicycle': 0.05,
  'motorcycle': 0.04,
  'dog': 0.03,
};
