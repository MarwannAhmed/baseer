import 'package:flutter_test/flutter_test.dart';
import 'package:baseer/core/app_settings.dart';

void main() {
  group('AppSettings', () {
    setUp(() {
      AppSettings().locale = 'ar';
    });

    test('singleton returns the same instance', () {
      final a = AppSettings();
      final b = AppSettings();
      expect(identical(a, b), isTrue);
    });

    test('default locale is ar', () {
      expect(AppSettings().locale, equals('ar'));
    });

    test('isAr is true when locale is ar', () {
      expect(AppSettings().isAr, isTrue);
    });

    test('isAr is false when locale is en', () {
      AppSettings().locale = 'en';
      expect(AppSettings().isAr, isFalse);
    });

    test('ttsLanguage is ar-EG when locale is ar', () {
      expect(AppSettings().ttsLanguage, equals('ar-EG'));
    });

    test('ttsLanguage is en-US when locale is en', () {
      AppSettings().locale = 'en';
      expect(AppSettings().ttsLanguage, equals('en-US'));
    });

    test('sttLocale mirrors ttsLanguage for ar', () {
      expect(AppSettings().sttLocale, equals('ar-EG'));
    });

    test('sttLocale mirrors ttsLanguage for en', () {
      AppSettings().locale = 'en';
      expect(AppSettings().sttLocale, equals('en-US'));
    });

    group('t() translation helper', () {
      test('returns Arabic string when locale is ar', () {
        AppSettings().locale = 'ar';
        expect(AppSettings().t('عربي', 'English'), equals('عربي'));
      });

      test('returns English string when locale is en', () {
        AppSettings().locale = 'en';
        expect(AppSettings().t('عربي', 'English'), equals('English'));
      });

      test('handles empty strings without error', () {
        expect(AppSettings().t('', ''), equals(''));
      });
    });
  });
}
