// lib/core/services/tts_narrator.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../app_settings.dart';

class TtsNarrator {
  TtsNarrator._({FlutterTts? tts}) : _tts = tts ?? FlutterTts();
  static final TtsNarrator instance = TtsNarrator._();

  @visibleForTesting
  static TtsNarrator forTest({FlutterTts? tts}) => TtsNarrator._(tts: tts);

  final FlutterTts _tts;
  bool _isSpeaking = false;
  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;
    await _tts.awaitSpeakCompletion(true);

    final languages = await _tts.getLanguages as List;
    final target = AppSettings().ttsLanguage;
    final prefix = target.split('-')[0];

    final lang = languages.contains(target)
        ? target
        : languages.firstWhere(
            (l) => l.toString().startsWith(prefix),
            orElse: () => languages.isNotEmpty ? languages.first.toString() : 'ar-EG',
          ).toString();

    await _tts.setLanguage(lang);
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);

    _tts.setCompletionHandler(() => _isSpeaking = false);
    _tts.setCancelHandler(() => _isSpeaking = false);
    _tts.setErrorHandler((_) => _isSpeaking = false);

    _inited = true;
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    if (!_inited) await init();
    if (_isSpeaking) {
      await _tts.stop();
      _isSpeaking = false;
    }
    _isSpeaking = true;
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }
}
