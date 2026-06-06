import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image/image.dart' as img;
import 'package:mockito/mockito.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:baseer/features/object_detection/domain/detection_result.dart';
import 'package:baseer/features/object_detection/domain/object_detector.dart';

class FakeFlutterTts extends Fake implements FlutterTts {
  final List<String> spoken = [];
  List<dynamic> languages = ['ar-EG', 'en-US'];
  String? selectedLanguage;
  bool stopped = false;
  bool autoComplete = true;
  VoidCallback? completionHandler;

  @override
  Future<dynamic> get getLanguages async => languages;

  @override
  Future<int?> setLanguage(String language) async {
    selectedLanguage = language;
    return 1;
  }

  @override
  Future<int?> awaitSpeakCompletion(bool awaitCompletion) async => 1;

  @override
  Future<int?> setSpeechRate(double rate) async => 1;

  @override
  Future<int?> setPitch(double pitch) async => 1;

  @override
  void setCompletionHandler(VoidCallback? callback) {
    completionHandler = callback;
  }

  @override
  void setCancelHandler(VoidCallback? callback) {}

  @override
  void setErrorHandler(void Function(dynamic)? callback) {}

  @override
  Future<dynamic> speak(String text, {bool focus = true}) async {
    spoken.add(text);
    if (autoComplete) completionHandler?.call();
    return 1;
  }

  @override
  Future<int?> stop() async {
    stopped = true;
    return 1;
  }
}

class FakeSpeechToText extends Fake implements SpeechToText {
  bool initResult = true;
  List<LocaleName> availableLocales = [];
  bool _isListening = false;

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    debugLogging = false,
    Duration finalTimeout = const Duration(milliseconds: 2000),
    List<SpeechConfigOption>? options,
  }) async =>
      initResult;

  @override
  Future<List<LocaleName>> locales({String? localeHint}) async =>
      availableLocales;

  @override
  bool get isListening => _isListening;

  @override
  Future<dynamic> listen({
    SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    cancelOnError,
    String? localeId,
    SpeechSoundLevelChange? onSoundLevelChange,
    SpeechListenOptions? listenOptions,
    ListenMode listenMode = ListenMode.confirmation,
    partialResults,
    onDevice,
    sampleRate,
  }) async {
    _isListening = true;
    return true;
  }

  @override
  Future<void> stop() async {
    _isListening = false;
  }
}

class FakeObjectDetector extends Fake implements ObjectDetector {
  List<DetectionResult> results = [];
  bool initCalled = false;
  bool disposeCalled = false;

  @override
  Future<void> init() async {
    initCalled = true;
  }

  @override
  Future<List<DetectionResult>> detect(img.Image image) async =>
      List<DetectionResult>.from(results);

  @override
  void dispose() {
    disposeCalled = true;
  }
}
