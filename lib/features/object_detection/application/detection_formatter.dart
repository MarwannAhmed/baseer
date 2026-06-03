import '../domain/detection_result.dart';

const Map<String, String> arabicClassNames = {
  'person': 'شخص',
  'bicycle': 'دراجة',
  'car': 'سيارة',
  'motorcycle': 'دراجة نارية',
  'airplane': 'طائرة',
  'bus': 'حافلة',
  'train': 'قطار',
  'truck': 'شاحنة',
  'boat': 'قارب',
  'traffic light': 'إشارة مرور',
  'fire hydrant': 'صنبور إطفاء',
  'stop sign': 'لافتة توقف',
  'parking meter': 'عداد توقف',
  'bench': 'مقعد',
  'bird': 'طائر',
  'cat': 'قطة',
  'dog': 'كلب',
  'horse': 'حصان',
  'sheep': 'خروف',
  'cow': 'بقرة',
  'elephant': 'فيل',
  'bear': 'دب',
  'zebra': 'حمار وحشي',
  'giraffe': 'زرافة',
  'backpack': 'حقيبة ظهر',
  'umbrella': 'مظلة',
  'handbag': 'حقيبة يد',
  'tie': 'ربطة عنق',
  'suitcase': 'حقيبة سفر',
  'frisbee': 'فريسبي',
  'skis': 'زلاجات',
  'snowboard': 'لوح ثلج',
  'sports ball': 'كرة رياضية',
  'kite': 'طائرة ورقية',
  'baseball bat': 'مضرب بيسبول',
  'baseball glove': 'قفاز بيسبول',
  'skateboard': 'لوح تزلج',
  'surfboard': 'لوح ركوب الأمواج',
  'tennis racket': 'مضرب تنس',
  'bottle': 'زجاجة',
  'wine glass': 'كأس نبيذ',
  'cup': 'كوب',
  'fork': 'شوكة',
  'knife': 'سكين',
  'spoon': 'ملعقة',
  'bowl': 'وعاء',
  'banana': 'موزة',
  'apple': 'تفاحة',
  'sandwich': 'ساندويتش',
  'orange': 'برتقالة',
  'broccoli': 'بروكلي',
  'carrot': 'جزرة',
  'hot dog': 'هوت دوغ',
  'pizza': 'بيتزا',
  'donut': 'دونات',
  'cake': 'كعكة',
  'chair': 'كرسي',
  'couch': 'أريكة',
  'potted plant': 'نبتة في وعاء',
  'bed': 'سرير',
  'dining table': 'طاولة طعام',
  'toilet': 'مرحاض',
  'tv': 'تلفاز',
  'laptop': 'حاسوب محمول',
  'mouse': 'فأرة حاسوب',
  'remote': 'ريموت كنترول',
  'keyboard': 'لوحة مفاتيح',
  'cell phone': 'هاتف محمول',
  'microwave': 'ميكروويف',
  'oven': 'فرن',
  'toaster': 'محمصة',
  'sink': 'حوض',
  'refrigerator': 'ثلاجة',
  'book': 'كتاب',
  'clock': 'ساعة',
  'vase': 'مزهرية',
  'scissors': 'مقص',
  'teddy bear': 'دمية دب',
  'hair drier': 'مجفف شعر',
  'toothbrush': 'فرشاة أسنان',
};

abstract final class DetectionFormatter {
  DetectionFormatter._();

  static String toSentence(
    List<DetectionResult> results, {
    bool isArabic = false,
    int maxObjects = 5,
  }) {
    if (results.isEmpty) {
      return isArabic ? 'لا يوجد أي شيء في المشهد.' : 'No objected detected.';
    }

    final shown = results.take(maxObjects).toList();

    if (isArabic) {
      return _buildArabic(shown);
    } else {
      return _buildEnglish(shown);
    }
  }

  static String _buildEnglish(List<DetectionResult> results) {
    final parts = results.map((result) {
      return 'A ${result.className} with ${result.confidenceScore} confidence '
          'found at top-left position ${result.boundingBox.x1.round()}, ${result.boundingBox.y1.round()} '
          'to bottom-right position ${result.boundingBox.x2.round()}, ${result.boundingBox.y2.round()}';
    }).toList();

    if (parts.length == 1) return 'I see ${parts[0]}.';
    final last = parts.removeLast();
    return 'I see ${parts.join(', ')}, and $last.';
  }

  static String _buildArabic(List<DetectionResult> results) {
    final parts = results.map((result) {
      final name = arabicClassNames[result.className] ?? result.className;
      return '$name بثقة ${result.confidenceScore} '
          'في الموضع ${result.boundingBox.x1.round()}، ${result.boundingBox.y1.round()} '
          'إلى ${result.boundingBox.x2.round()}، ${result.boundingBox.y2.round()}';
    }).toList();

    if (parts.length == 1) return 'أرى ${parts[0]}.';
    final last = parts.removeLast();
    return 'أرى ${parts.join('، ')}، و$last.';
  }
}
