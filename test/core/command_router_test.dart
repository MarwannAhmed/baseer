import 'package:flutter_test/flutter_test.dart';
import 'package:baseer/core/command_router.dart';

void main() {
  group('CommandRouter', () {
    group('color detection keywords', () {
      test("'لون' routes to detectColor", () {
        expect(CommandRouter.route('لون'), AppCommand.detectColor);
      });

      test("'ما لون هذا' routes to detectColor", () {
        expect(CommandRouter.route('ما لون هذا'), AppCommand.detectColor);
      });

      test("'ألوان' routes to detectColor", () {
        expect(CommandRouter.route('ألوان'), AppCommand.detectColor);
      });

      test("'اللون' routes to detectColor", () {
        expect(CommandRouter.route('اللون'), AppCommand.detectColor);
      });

      test("'لونه' routes to detectColor", () {
        expect(CommandRouter.route('لونه'), AppCommand.detectColor);
      });

      test("'لوني' routes to detectColor", () {
        expect(CommandRouter.route('لوني'), AppCommand.detectColor);
      });
    });

    group('text extraction keywords', () {
      test("'اقرأ' routes to readText", () {
        expect(CommandRouter.route('اقرأ'), AppCommand.readText);
      });

      test("'نص' routes to readText", () {
        expect(CommandRouter.route('نص'), AppCommand.readText);
      });

      test("'مكتوب' routes to readText", () {
        expect(CommandRouter.route('مكتوب'), AppCommand.readText);
      });

      test("'قراءة' routes to readText", () {
        expect(CommandRouter.route('قراءة'), AppCommand.readText);
      });

      test("'كلمة' routes to readText", () {
        expect(CommandRouter.route('كلمة'), AppCommand.readText);
      });

      test("'كلمات' routes to readText", () {
        expect(CommandRouter.route('كلمات'), AppCommand.readText);
      });

      test("'اقراء النص' routes to readText", () {
        expect(CommandRouter.route('اقراء النص'), AppCommand.readText);
      });
    });

    group('object detection keywords', () {
      test("'ما هذا' routes to detectObject", () {
        expect(CommandRouter.route('ما هذا'), AppCommand.detectObject);
      });

      test("'ماذا أمامي' routes to detectObject", () {
        expect(CommandRouter.route('ماذا أمامي'), AppCommand.detectObject);
      });

      test("'اكتشف' routes to detectObject", () {
        expect(CommandRouter.route('اكتشف'), AppCommand.detectObject);
      });

      test("'كشف' routes to detectObject", () {
        expect(CommandRouter.route('كشف'), AppCommand.detectObject);
      });

      test("'تعرف' routes to detectObject", () {
        expect(CommandRouter.route('تعرف'), AppCommand.detectObject);
      });
    });

    group('default describe fallback', () {
      test('empty string routes to describe', () {
        expect(CommandRouter.route(''), AppCommand.describe);
      });

      test('unknown Arabic text routes to describe', () {
        expect(CommandRouter.route('مرحباً كيف حالك'), AppCommand.describe);
      });

      test('English text routes to describe', () {
        expect(CommandRouter.route('hello world'), AppCommand.describe);
      });

      test('whitespace-only routes to describe', () {
        expect(CommandRouter.route('   '), AppCommand.describe);
      });
    });

    group('keyword inside longer sentence', () {
      test("color keyword embedded in sentence routes to detectColor", () {
        expect(
          CommandRouter.route('أريد معرفة ما لون الجدار'),
          AppCommand.detectColor,
        );
      });

      test("text keyword embedded in sentence routes to readText", () {
        expect(
          CommandRouter.route('من فضلك اقرأ ما هو مكتوب على اللافتة'),
          AppCommand.readText,
        );
      });
    });

    group('priority ordering', () {
      test('color keyword takes priority over text keyword', () {
        // 'لون' is color, but text 'نص' is also present — color wins
        expect(CommandRouter.route('ما لون النص'), AppCommand.detectColor);
      });
    });
  });
}
