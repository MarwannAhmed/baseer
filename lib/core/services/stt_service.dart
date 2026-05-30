// lib/core/services/stt_service.dart

import 'package:speech_to_text/speech_to_text.dart';
import '../app_settings.dart';

class STTService {
  final SpeechToText _speech = SpeechToText();
  String localeId  = 'ar';
  bool   available = false;

  Future<void> init() async {
    available = await _speech.initialize();
    if (!available) return;

    final target  = AppSettings().sttLocale;         // e.g. 'ar-EG'
    final prefix  = target.split('-')[0];            // e.g. 'ar'
    final locales = await _speech.locales();

    if (locales.any((l) => l.localeId == target)) {
      localeId = target;
    } else if (locales.any((l) => l.localeId.startsWith(prefix))) {
      localeId = locales.firstWhere((l) => l.localeId.startsWith(prefix)).localeId;
    } else {
      localeId = locales.isNotEmpty ? locales.first.localeId : 'ar';
    }
  }

  Future<void> startListening(void Function(String) onResult) async {
    if (!available) return;
    if (_speech.isListening) await _speech.stop();

    await _speech.listen(
      localeId:    localeId,
      listenOptions: SpeechListenOptions(
        partialResults: false,
        cancelOnError:  false,
      ),
      listenFor: const Duration(seconds: 15),
      pauseFor:  const Duration(seconds: 5),
      onResult: (result) {
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          onResult(result.recognizedWords);
        }
      },
    );
  }

  Future<void> stopListening() async {
    if (!available) return;
    await _speech.stop();
  }
}
