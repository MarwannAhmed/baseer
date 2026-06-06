import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:baseer/core/services/stt_service.dart';
import '../../helpers/fakes.dart';

void main() {
  group('STTService', () {
    late FakeSpeechToText fakeSpeech;
    late STTService stt;

    setUp(() {
      fakeSpeech = FakeSpeechToText();
      stt = STTService(speech: fakeSpeech);
    });

    group('init()', () {
      test('sets available=false and returns early when initialize() returns false', () async {
        fakeSpeech.initResult = false;
        await stt.init();
        expect(stt.available, isFalse);
      });

      test('sets available=true when initialize() returns true', () async {
        fakeSpeech.initResult = true;
        fakeSpeech.availableLocales = [LocaleName('ar-EG', 'Arabic (Egypt)')];
        await stt.init();
        expect(stt.available, isTrue);
      });

      test('selects exact ar-EG locale when available', () async {
        fakeSpeech.initResult = true;
        fakeSpeech.availableLocales = [
          LocaleName('en-US', 'English (US)'),
          LocaleName('ar-EG', 'Arabic (Egypt)'),
        ];
        await stt.init();
        expect(stt.localeId, equals('ar-EG'));
      });

      test('falls back to ar-SA when ar-EG not present', () async {
        fakeSpeech.initResult = true;
        fakeSpeech.availableLocales = [
          LocaleName('en-US', 'English (US)'),
          LocaleName('ar-SA', 'Arabic (Saudi Arabia)'),
        ];
        await stt.init();
        expect(stt.localeId, equals('ar-SA'));
      });

      test('falls back to first locale when no Arabic locale present', () async {
        fakeSpeech.initResult = true;
        fakeSpeech.availableLocales = [
          LocaleName('fr-FR', 'French'),
          LocaleName('de-DE', 'German'),
        ];
        await stt.init();
        expect(stt.localeId, equals('fr-FR'));
      });

      test('falls back to ar when locales list is empty', () async {
        fakeSpeech.initResult = true;
        fakeSpeech.availableLocales = [];
        await stt.init();
        expect(stt.localeId, equals('ar'));
      });
    });

    group('startListening()', () {
      test('does nothing when available is false', () async {
        fakeSpeech.initResult = false;
        await stt.init();
        expect(fakeSpeech.isListening, isFalse);
        await stt.startListening((_) {});
        expect(fakeSpeech.isListening, isFalse);
      });
    });

    group('stopListening()', () {
      test('does nothing when available is false', () async {
        fakeSpeech.initResult = false;
        await stt.init();
        await stt.stopListening();
        expect(fakeSpeech.isListening, isFalse);
      });

      test('calls stop when available', () async {
        fakeSpeech.initResult = true;
        fakeSpeech.availableLocales = [LocaleName('ar-EG', 'Arabic')];
        await stt.init();
        await stt.startListening((_) {});
        expect(fakeSpeech.isListening, isTrue);
        await stt.stopListening();
        expect(fakeSpeech.isListening, isFalse);
      });
    });
  });
}
