// lib/core/stt_service.dart

import 'package:speech_to_text/speech_to_text.dart';

/// Thin wrapper around [SpeechToText].
///
/// Key fixes vs original:
///   1. [onResult] now checks [result.finalResult] so the callback is only
///      triggered once per utterance, not on every partial transcript.
///   2. Debug print statements removed.
class STTService {
  final SpeechToText _speech = SpeechToText();
  String localeId = 'ar';

  Future<void> init() async {
    await _speech.initialize();

    final locales = await _speech.locales();
    localeId =
        locales.any((l) => l.localeId == 'ar_EG') ? 'ar_EG' : 'ar';
  }

  /// Starts listening and calls [onResult] exactly once with the final
  /// recognised text.  Safe to call even if already listening.
  Future<void> startListening(void Function(String) onResult) async {
    if (_speech.isListening) await _speech.stop();

    await _speech.listen(
      localeId: localeId,
      listenOptions: SpeechListenOptions(
        partialResults: false,
        cancelOnError: true,
      ),
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 5),
      onResult: (result) {
        // Guard: only fire once the engine has committed the transcript.
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          onResult(result.recognizedWords);
        }
      },
    );
  }

  Future<void> stopListening() async => _speech.stop();
}