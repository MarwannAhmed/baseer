import 'package:flutter_test/flutter_test.dart';
import 'package:baseer/core/services/tts_service.dart';
import '../../helpers/fakes.dart';

void main() {
  group('TTSService', () {
    group('forTest instance', () {
      late FakeFlutterTts fakeTts;
      late TTSService service;

      setUp(() {
        fakeTts = FakeFlutterTts();
        service = TTSService.forTest(tts: fakeTts);
      });

      group('speak()', () {
        test('returns immediately without speaking when text is empty', () async {
          await service.speak('');
          expect(fakeTts.spoken, isEmpty);
        });

        test('calls init() when not yet initialised', () async {
          await service.speak('مرحبا');
          // init sets language — selectedLanguage is non-null after init
          expect(fakeTts.selectedLanguage, isNotNull);
          expect(fakeTts.spoken, contains('مرحبا'));
        });

        test('calls stop() before speaking when already speaking', () async {
          fakeTts.autoComplete = false; // prevent _isSpeaking from resetting
          await service.speak('first'); // _isSpeaking stays true

          fakeTts.stopped = false;
          await service.speak('second');
          expect(fakeTts.stopped, isTrue);
        });
      });

      group('stop()', () {
        test('delegates to underlying tts.stop()', () async {
          await service.stop();
          expect(fakeTts.stopped, isTrue);
        });
      });

      group('init() language selection', () {
        test('selects exact ar-EG match', () async {
          fakeTts.languages = ['en-US', 'ar-EG', 'fr-FR'];
          await service.init();
          expect(fakeTts.selectedLanguage, equals('ar-EG'));
        });

        test('falls back to ar-SA when ar-EG absent', () async {
          fakeTts.languages = ['en-US', 'ar-SA'];
          await service.init();
          expect(fakeTts.selectedLanguage, equals('ar-SA'));
        });

        test('falls back to first language when no Arabic available', () async {
          fakeTts.languages = ['fr-FR', 'de-DE'];
          await service.init();
          expect(fakeTts.selectedLanguage, equals('fr-FR'));
        });

        test('falls back to ar-EG when language list is empty', () async {
          fakeTts.languages = [];
          await service.init();
          expect(fakeTts.selectedLanguage, equals('ar-EG'));
        });
      });
    });
  });
}
