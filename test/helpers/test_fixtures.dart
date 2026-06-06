import 'package:baseer/features/analysis/domain/detected_object.dart';
import 'package:baseer/features/distance_estimation/domain/object_size_prior.dart';

DetectedObject makeDetectedObject({
  String label = 'car',
  double confidence = 0.9,
  int x1 = 10,
  int y1 = 10,
  int x2 = 110,
  int y2 = 110,
  String colorEn = '',
  String colorAr = '',
  int distanceCm = 0,
}) {
  return DetectedObject(
    label: label,
    confidence: confidence,
    bbox: {'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2},
    center: {
      'x': ((x1 + x2) / 2).round(),
      'y': ((y1 + y2) / 2).round(),
    },
    size: {'width': x2 - x1, 'height': y2 - y1},
    colorEn: colorEn,
    colorAr: colorAr,
    distanceCm: distanceCm,
  );
}

ObjectSizePrior makeObjectSizePrior({
  String className = 'person',
  double typicalHeightM = 1.70,
  double typicalWidthM = 0.45,
  double heightStdM = 0.12,
  double widthStdM = 0.10,
  double heightConfidence = 0.85,
  double widthConfidence = 0.60,
}) {
  return ObjectSizePrior(
    className: className,
    typicalHeightM: typicalHeightM,
    typicalWidthM: typicalWidthM,
    heightStdM: heightStdM,
    widthStdM: widthStdM,
    heightConfidence: heightConfidence,
    widthConfidence: widthConfidence,
  );
}
