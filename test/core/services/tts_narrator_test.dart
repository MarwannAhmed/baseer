import 'package:flutter_test/flutter_test.dart';
import 'package:baseer/core/services/tts_narrator.dart';
import '../../helpers/fakes.dart';

void main() {
  group('TtsNarrator', () {
    group('forTest instance', () {
      late FakeFlutterTts fakeTts;
      late TtsNarrator narrator;

      setUp(() {
        fakeTts = FakeFlutterTts();
        narrator = TtsNarrator.forTest(tts: fakeTts);
      });

      group('init()', () {
        test('initialises TTS on first call', () async {
          await narrator.init();
          expect(fakeTts.selectedLanguage, isNotNull);
        });

        test('is guarded: second call skips re-initialisation', () async {
          await narrator.init();
          fakeTts.selectedLanguage = null;
          await narrator.init(); // should return early
          expect(fakeTts.selectedLanguage, isNull); // setLanguage not called again
        });

        test('selects exact ar-EG match', () async {
          fakeTts.languages = ['en-US', 'ar-EG'];
          await narrator.init();
          expect(fakeTts.selectedLanguage, equals('ar-EG'));
        });

        test('falls back to language-prefix match when ar-EG absent', () async {
          fakeTts.languages = ['en-US', 'ar-MA'];
          await narrator.init();
          expect(fakeTts.selectedLanguage, equals('ar-MA'));
        });

        test('falls back to first language when no Arabic present', () async {
          fakeTts.languages = ['fr-FR', 'de-DE'];
          await narrator.init();
          expect(fakeTts.selectedLanguage, equals('fr-FR'));
        });

        test('falls back to ar-EG when language list is empty', () async {
          fakeTts.languages = [];
          await narrator.init();
          expect(fakeTts.selectedLanguage, equals('ar-EG'));
        });
      });

      group('speak()', () {
        test('returns immediately without speaking when text is empty', () async {
          await narrator.speak('');
          expect(fakeTts.spoken, isEmpty);
        });

        test('speaks non-empty text', () async {
          await narrator.speak('مرحبا');
          expect(fakeTts.spoken, contains('مرحبا'));
        });

        test('calls stop() before speaking when already speaking', () async {
          fakeTts.autoComplete = false;
          await narrator.speak('first');
          fakeTts.stopped = false;
          await narrator.speak('second');
          expect(fakeTts.stopped, isTrue);
        });
      });

      group('stop()', () {
        test('delegates to underlying tts.stop()', () async {
          await narrator.stop();
          expect(fakeTts.stopped, isTrue);
        });
      });
    });
  });
}
