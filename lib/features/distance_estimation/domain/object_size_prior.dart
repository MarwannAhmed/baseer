class ObjectSizePrior {
  final String className;
  final double typicalHeightM;
  final double typicalWidthM;
  final double heightStdM;
  final double widthStdM;
  final double heightConfidence;
  final double widthConfidence;

  const ObjectSizePrior({
    required this.className,
    required this.typicalHeightM,
    required this.typicalWidthM,
    required this.heightStdM,
    required this.widthStdM,
    required this.heightConfidence,
    required this.widthConfidence,
  });
}
