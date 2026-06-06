class FootPoint {

  final double u;
  final double v;

  const FootPoint({
    required this.u, 
    required this.v
  });

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
    final v = y2.toDouble().clamp(0.0, imageHeight - 1.0);
    return FootPoint(u: u, v: v);
  }

}