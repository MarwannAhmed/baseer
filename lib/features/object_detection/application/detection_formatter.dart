import 'package:baseer/features/analysis/domain/detected_object.dart';

const Map<String, String> _cocoArabic = {
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

  static String toSentenceFromObjects(
    List<DetectedObject> objects, {
    bool isArabic = true,
    int maxObjects = 5,
  }) {
    if (objects.isEmpty) {
      return isArabic ? 'لا يوجد أي شيء في المشهد.' : 'Nothing detected.';
    }

    final shown = objects.take(maxObjects).toList();
    return isArabic ? _buildArabicObjects(shown) : _buildEnglishObjects(shown);
  }

  static String _buildEnglishObjects(List<DetectedObject> objects) {
    final parts = objects.map((object) {
      final color = object.colorEn.isNotEmpty ? '${object.colorEn} ' : '';
      final distance = object.distanceCm > 0
          ? ' at distance ${object.distanceCm} cm'
          : '';
      return 'a $color${object.label}$distance';
    }).toList();

    if (parts.length == 1) {
      return 'I see ${parts[0]}.';
    }
    final last = parts.removeLast();
    return 'I see ${parts.join(', ')}, and $last.';
  }

  static String _buildArabicObjects(List<DetectedObject> objects) {
    final parts = objects.map((object) {
      final name = _cocoArabic[object.label] ?? object.label;
      final color = object.colorAr.isNotEmpty ? ' ${object.colorAr}' : '';
      final distance = object.distanceCm > 0
          ? ' على بعد ${object.distanceCm} سم'
          : '';
      return '$name$color$distance';
    }).toList();

    if (parts.length == 1) {
      return 'أرى ${parts[0]}.';
    }
    final last = parts.removeLast();
    return 'أرى ${parts.join('، ')}، و$last.';
  }
}
