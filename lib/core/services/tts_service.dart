// lib/core/services/tts_service.dart
//
// Singleton TTS wrapper.  Using a singleton means every screen shares the
// same underlying engine instance — no duplicate initialisation, no language
// mismatch between onboarding and the camera page.
//
// awaitSpeakCompletion(true) makes speak() block until the utterance is done.
// This prevents the "I'm listening" announcement from overlapping with STT.

import 'package:flutter_tts/flutter_tts.dart';
import '../app_settings.dart';

class TTSService {
  // ── Singleton ───────────────────────────────────────────────────────────────
  static final TTSService _i = TTSService._();
  factory TTSService() => _i;
  TTSService._();

  // ── State ───────────────────────────────────────────────────────────────────
  final FlutterTts _tts        = FlutterTts();
  bool             _isSpeaking = false;
  bool             _inited     = false;

  // ── Init ────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    // Make speak() truly block until utterance finishes.
    // This is critical so STT doesn't start while TTS audio is still playing.
    await _tts.awaitSpeakCompletion(true);

    final languages = await _tts.getLanguages as List;
    final target    = AppSettings().ttsLanguage; // e.g. 'ar-EG' or 'en-US'
    final prefix    = target.split('-')[0];       // e.g. 'ar' or 'en'

    // Prefer exact match, fall back to same language family, then Arabic.
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
    _tts.setCancelHandler(()    => _isSpeaking = false);
    _tts.setErrorHandler((_)    => _isSpeaking = false);

    _inited = true;
  }

  // ── Speak ───────────────────────────────────────────────────────────────────

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
