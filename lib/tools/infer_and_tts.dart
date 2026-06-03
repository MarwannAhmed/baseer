import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:baseer/features/color_recognition/application/color_detector_svm.dart';

/// Run color inference on an image (bytes) and speak the result using flutter_tts.
/// Returns the English label on success, or 'error'.
class InferAndTts {
  final FlutterTts _tts = FlutterTts();

  InferAndTts();

  Future<void> _speak(String text, {String? lang}) async {
    if (lang != null) await _tts.setLanguage(lang);
    await _tts.speak(text);
  }

  Future<String> inferAndSpeakFromFile(String path, {bool speakArabic = false}) async {
    try {
      final bytes = await File(path).readAsBytes();
      return await inferAndSpeakFromBytes(bytes, speakArabic: speakArabic);
    } catch (e) {
      debugPrint('[infer_and_tts] Error reading file $path: $e');
      return 'error';
    }
  }

  Future<String> inferAndSpeakFromBytes(Uint8List bytes, {bool speakArabic = false}) async {
    try {
      final img.Image? image = img.decodeImage(bytes);
      if (image == null) {
        debugPrint('[infer_and_tts] Failed to decode image');
        return 'error';
      }

      await SvmColorClassifier.instance.init();
      final detector = ColorDetectorSvm();
      await detector.setFrame(image);
      final result = detector.detect(0, 0, image.width, image.height);

      final en = result.colorEn;
      final ar = result.colorAr;

      // Speak English label, then Arabic if requested.
      try {
        await _tts.setSpeechRate(0.5);
        await _speak(en, lang: 'en-US');
        if (speakArabic) {
          await Future.delayed(const Duration(milliseconds: 300));
          await _speak(ar, lang: 'ar');
        }
      } catch (e) {
        debugPrint('[infer_and_tts] TTS error: $e');
      }

      return en;
    } catch (e) {
      debugPrint('[infer_and_tts] Error: $e');
      return 'error';
    }
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}
