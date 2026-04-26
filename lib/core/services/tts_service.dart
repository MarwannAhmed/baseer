// lib/core/tts_service.dart

import 'package:flutter_tts/flutter_tts.dart';

/// Thin wrapper around [FlutterTts].
///
/// Key fixes vs original:
///   1. Completion/cancel/error handlers are registered once in [init],
///      not inside every [speak] call — so [_isSpeaking] always resets.
///   2. [speak] interrupts any in-progress speech instead of silently
///      dropping the new request when [_isSpeaking] is true.
class TTSService {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;

  Future<void> init() async {
    final languages = await _tts.getLanguages as List;
    if (languages.contains('ar-EG')) {
      await _tts.setLanguage('ar-EG');
    } else if (languages.contains('ar')) {
      await _tts.setLanguage('ar');
    }
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);

    // Register handlers once so _isSpeaking is always reset correctly.
    _tts.setCompletionHandler(() => _isSpeaking = false);
    _tts.setCancelHandler(() => _isSpeaking = false);
    _tts.setErrorHandler((_) => _isSpeaking = false);
  }

  /// Speaks [text], interrupting any current speech first.
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
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