import 'package:baseer/features/analysis/domain/detected_object.dart';

import '../domain/detection_result.dart';

const Map<String, String> _cocoArabic = {
  'person':         'شخص',
  'bicycle':        'دراجة',
  'car':            'سيارة',
  'motorcycle':     'دراجة نارية',
  'airplane':       'طائرة',
  'bus':            'حافلة',
  'train':          'قطار',
  'truck':          'شاحنة',
  'boat':           'قارب',
  'traffic light':  'إشارة مرور',
  'fire hydrant':   'صنبور إطفاء',
  'stop sign':      'لافتة توقف',
  'parking meter':  'عداد توقف',
  'bench':          'مقعد',
  'bird':           'طائر',
  'cat':            'قطة',
  'dog':            'كلب',
  'horse':          'حصان',
  'sheep':          'خروف',
  'cow':            'بقرة',
  'elephant':       'فيل',
  'bear':           'دب',
  'zebra':          'حمار وحشي',
  'giraffe':        'زرافة',
  'backpack':       'حقيبة ظهر',
  'umbrella':       'مظلة',
  'handbag':        'حقيبة يد',
  'tie':            'ربطة عنق',
  'suitcase':       'حقيبة سفر',
  'frisbee':        'فريسبي',
  'skis':           'زلاجات',
  'snowboard':      'لوح ثلج',
  'sports ball':    'كرة رياضية',
  'kite':           'طائرة ورقية',
  'baseball bat':   'مضرب بيسبول',
  'baseball glove': 'قفاز بيسبول',
  'skateboard':     'لوح تزلج',
  'surfboard':      'لوح ركوب الأمواج',
  'tennis racket':  'مضرب تنس',
  'bottle':         'زجاجة',
  'wine glass':     'كأس نبيذ',
  'cup':            'كوب',
  'fork':           'شوكة',
  'knife':          'سكين',
  'spoon':          'ملعقة',
  'bowl':           'وعاء',
  'banana':         'موزة',
  'apple':          'تفاحة',
  'sandwich':       'ساندويتش',
  'orange':         'برتقالة',
  'broccoli':       'بروكلي',
  'carrot':         'جزرة',
  'hot dog':        'هوت دوغ',
  'pizza':          'بيتزا',
  'donut':          'دونات',
  'cake':           'كعكة',
  'chair':          'كرسي',
  'couch':          'أريكة',
  'potted plant':   'نبتة في وعاء',
  'bed':            'سرير',
  'dining table':   'طاولة طعام',
  'toilet':         'مرحاض',
  'tv':             'تلفاز',
  'laptop':         'حاسوب محمول',
  'mouse':          'فأرة حاسوب',
  'remote':         'ريموت كنترول',
  'keyboard':       'لوحة مفاتيح',
  'cell phone':     'هاتف محمول',
  'microwave':      'ميكروويف',
  'oven':           'فرن',
  'toaster':        'محمصة',
  'sink':           'حوض',
  'refrigerator':   'ثلاجة',
  'book':           'كتاب',
  'clock':          'ساعة',
  'vase':           'مزهرية',
  'scissors':       'مقص',
  'teddy bear':     'دمية دب',
  'hair drier':     'مجفف شعر',
  'toothbrush':     'فرشاة أسنان',
};

abstract final class DetectionFormatter {
  DetectionFormatter._();

  /// Builds a spoken sentence from a list of detection results.
  ///
  /// [isArabic] — pass AppSettings().isAr if you use that singleton.
  /// [maxObjects] — cap how many objects are mentioned (avoids very long TTS).
  static String toSentence(
    List<DetectionResult> results, {
    bool isArabic = false,
    int maxObjects = 5,
  }) {
    if (results.isEmpty) {
      return isArabic ? 'لا يوجد أي شيء في المشهد.' : 'Nothing detected.';
    }

    final shown = results.take(maxObjects).toList();

    if (isArabic) {
      return _buildArabic(shown);
    } else {
      return _buildEnglish(shown);
    }
  }

  static String toSentenceFromObjects(
    List<DetectedObject> objects, {
    bool isArabic = false,
    int maxObjects = 5,
  }) {
    if (objects.isEmpty) {
      return isArabic ? 'لا يوجد أي شيء في المشهد.' : 'Nothing detected.';
    }

    final shown = objects.take(maxObjects).toList();

    if (isArabic) {
      return _buildArabicObjects(shown);
    } else {
      return _buildEnglishObjects(shown);
    }
  }

  // ── English ────────────────────────────────────────────────────────────────

  static String _buildEnglish(List<DetectionResult> results) {
    final parts = results.map((r) {
      final b = r.boundingBox;
      return 'a ${r.label} with ${r.confidencePercent} confidence '
          'at position ${b.x1.round()}, ${b.y1.round()} '
          'to ${b.x2.round()}, ${b.y2.round()}';
    }).toList();

    if (parts.length == 1) return 'I see ${parts[0]}.';
    final last = parts.removeLast();
    return 'I see ${parts.join(', ')}, and $last.';
  }

  // ── Arabic ─────────────────────────────────────────────────────────────────

  static String _buildArabic(List<DetectionResult> results) {
    final parts = results.map((r) {
      final name = _cocoArabic[r.label] ?? r.label;
      final b    = r.boundingBox;
      return '$name بثقة ${r.confidencePercent} '
          'في الموضع ${b.x1.round()}، ${b.y1.round()} '
          'إلى ${b.x2.round()}، ${b.y2.round()}';
    }).toList();

    if (parts.length == 1) return 'أرى ${parts[0]}.';
    final last = parts.removeLast();
    return 'أرى ${parts.join('، ')}، و$last.';
  }

  static String _buildEnglishObjects(List<DetectedObject> objects) {
    final parts = objects.map((o) {
      final b = o.bbox;
      final distance = o.distanceCm > 0
          ? ' at distance ${o.distanceCm} cm'
          : '';
      final percent = (o.confidence * 100).round();
      return 'a ${o.label} with $percent% confidence '
          'at position ${b['x1'] ?? 0}, ${b['y1'] ?? 0} '
          'to ${b['x2'] ?? 0}, ${b['y2'] ?? 0}$distance';
    }).toList();

    if (parts.length == 1) return 'I see ${parts[0]}.';
    final last = parts.removeLast();
    return 'I see ${parts.join(', ')}, and $last.';
  }

  static String _buildArabicObjects(List<DetectedObject> objects) {
    final parts = objects.map((o) {
      final name = _cocoArabic[o.label] ?? o.label;
      final b = o.bbox;
      final distance = o.distanceCm > 0
          ? ' على بعد ${o.distanceCm} سم'
          : '';
      final percent = (o.confidence * 100).round();
      return '$name بثقة $percent% '
          'في الموضع ${b['x1'] ?? 0}، ${b['y1'] ?? 0} '
          'إلى ${b['x2'] ?? 0}، ${b['y2'] ?? 0}$distance';
    }).toList();

    if (parts.length == 1) return 'أرى ${parts[0]}.';
    final last = parts.removeLast();
    return 'أرى ${parts.join('، ')}، و$last.';
  }
}