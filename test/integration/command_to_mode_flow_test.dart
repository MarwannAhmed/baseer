import 'package:flutter_test/flutter_test.dart';
import 'package:baseer/core/command_router.dart';

void main() {
  group('Command → AppCommand integration', () {
    test('full color phrase routes to detectColor', () {
      expect(
        CommandRouter.route('أريد معرفة ما لون الجدار أمامي'),
        AppCommand.detectColor,
      );
    });

    test('full text phrase routes to readText', () {
      expect(
        CommandRouter.route('من فضلك اقرأ ما هو مكتوب على اللافتة'),
        AppCommand.readText,
      );
    });

    test('full object phrase routes to detectObject', () {
      expect(
        CommandRouter.route('ماذا أمامي الآن'),
        AppCommand.detectObject,
      );
    });

    test('generic description phrase routes to describe', () {
      expect(
        CommandRouter.route('أخبرني عن المشهد'),
        AppCommand.describe,
      );
    });

    test('text keyword in same phrase as color: color wins', () {
      expect(
        CommandRouter.route('اقرأ لون الجدار'),
        AppCommand.detectColor,
      );
    });

    test('empty string defaults to describe', () {
      expect(CommandRouter.route(''), AppCommand.describe);
    });

    test('all four AppCommand values are reachable', () {
      final results = {
        CommandRouter.route('لون'),
        CommandRouter.route('اقرأ'),
        CommandRouter.route('ما هذا'),
        CommandRouter.route('مرحبا'),
      };
      expect(results, containsAll(AppCommand.values));
    });
  });
}
