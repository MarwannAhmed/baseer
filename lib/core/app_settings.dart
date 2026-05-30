// lib/core/app_settings.dart

class AppSettings {
  static final AppSettings _i = AppSettings._();
  factory AppSettings() => _i;
  AppSettings._();

  /// 'ar' (Arabic) or 'en' (English)
  String locale = 'ar';

  bool get isAr => locale == 'ar';

  String get ttsLanguage => isAr ? 'ar-EG' : 'en-US';
  String get sttLocale   => isAr ? 'ar-EG' : 'en-US';

  /// Short helper for inline bilingual strings.
  String t(String ar, String en) => isAr ? ar : en;
}
