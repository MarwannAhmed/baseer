import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:speech_to_text/speech_to_text.dart';

import 'package:baseer/core/services/tts_narrator.dart';
import 'package:baseer/features/color_recognition/application/color_detector.dart';
import 'package:baseer/features/text_extraction/application/text_extractor.dart';

img.Image? _decodeImageBytes(Uint8List bytes) => img.decodeImage(bytes);

// ─── Design tokens ──────────────────────────────────────────────────────────
const _kSteel = Color(0xFF2D6A8E);
const _kWhite = Colors.white;
const _kBlack = Colors.black;
const _kSurface = Color(0xCC000000);
const _kSurfaceDim = Color(0x99000000);
const _kBorder = Color(0x33FFFFFF);
const _kTextMuted = Color(0x99FFFFFF);

// ─── Entry point ─────────────────────────────────────────────────────────────
class LiveCameraPage extends StatefulWidget {
  const LiveCameraPage({super.key});

  @override
  State<LiveCameraPage> createState() => _LiveCameraPageState();
}

class _LiveCameraPageState extends State<LiveCameraPage>
    with TickerProviderStateMixin {
  // ── Backend ──
  static const String _analyzeEndpoint = '/analyze';
  String get _baseUri =>
      dotenv.env['BASE_URI']?.trim() ?? 'http://127.0.0.1:8000';

  // ── Camera / speech ──
  CameraController? _controller;
  late List<CameraDescription> _cameras;
  final SpeechToText _speech = SpeechToText();
  final ColorDetector _colorDetector = ColorDetector();

  // ── Silent input / mode overlay ──
  bool _showSilentInput = false;
  final TextEditingController _silentInputCtrl = TextEditingController();
  bool _modeOverlayVisible = false;
  String _modeOverlayLabel = '';
  Timer? _modeOverlayTimer;

  // ── State ──
  bool _isListening = false;
  bool _isProcessing = false;
  String _lastCommand = 'كشف';
  String _sttLocale = 'ar_EG';
  String _lastResult = '';
  _AppMode _activeMode = _AppMode.detect;

  // ── Animations ──
  late AnimationController _pulseController;
  late AnimationController _scanLineController;
  late AnimationController _resultFadeController;
  late Animation<double> _pulseAnim;
  late Animation<double> _scanLineAnim;
  late Animation<double> _resultFadeAnim;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeEverything();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _scanLineAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.linear),
    );

    _resultFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _resultFadeAnim = CurvedAnimation(
      parent: _resultFadeController,
      curve: Curves.easeOut,
    );
  }

  // ─── Init ────────────────────────────────────────────────────────────────
  Future<void> _initializeEverything() async {
    _cameras = await availableCameras();
    _controller = CameraController(
      _cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _controller!.initialize();

    // Show camera preview immediately — don't wait for speech services.
    if (!mounted) return;
    setState(() {});

    await _speech.initialize(
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') &&
            mounted && _isListening) {
          setState(() => _isListening = false);
        }
      },
      onError: (error) {
        if (mounted && _isListening) {
          setState(() => _isListening = false);
        }
      },
    );

    final locales = await _speech.locales();
    _sttLocale = locales.any((l) => l.localeId == 'ar_EG') ? 'ar_EG' : 'ar';

    await TtsNarrator.instance.init();
  
    await TextExtractor.initialize();

    if (!mounted) return;
    await TtsNarrator.instance.speak('بصير جاهز.');
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    await TtsNarrator.instance.speak('انقر مرتين في أي مكان على الشاشة للتحدث.');
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    await TtsNarrator.instance.speak('اضغط بشكل مطوّل للتقاط صورة وتحليلها.');
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    await TtsNarrator.instance.speak('امسح لليسار أو لليمين لتغيير الوضع.');
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    await TtsNarrator.instance.speak('الوضع الحالي: كشف.');
  }

  // ─── Mode switch ─────────────────────────────────────────────────────────
  Future<void> _switchMode(_AppMode mode) async {
    if (_activeMode == mode) return;
    HapticFeedback.selectionClick();
    setState(() {
      _activeMode = mode;
      _lastCommand = mode.defaultCommand;
      _modeOverlayVisible = true;
      _modeOverlayLabel = mode.label;
    });
    _modeOverlayTimer?.cancel();
    _modeOverlayTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _modeOverlayVisible = false);
    });
    await TtsNarrator.instance.speak(mode.announcementAr);
  }

  // ─── STT ─────────────────────────────────────────────────────────────────
  Future<void> _startListening() async {
    if (_isListening || _isProcessing) return;
    HapticFeedback.mediumImpact();

    await TtsNarrator.instance.stop();
    await Future.delayed(const Duration(milliseconds: 150));

    setState(() => _isListening = true);

    final started = await _speech.listen(
      localeId: _sttLocale,
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 4),
      listenOptions: SpeechListenOptions(
        partialResults: false,
        cancelOnError: true,
      ),
      onResult: (result) async {
        if (!result.finalResult) return;
        setState(() => _isListening = false);
        await _speech.stop();
        if (result.recognizedWords.isNotEmpty) {
          _lastCommand = result.recognizedWords;
          await TtsNarrator.instance.speak('قلت: ${result.recognizedWords}');
        } else {
          await TtsNarrator.instance.speak('لم أسمع شيئاً. حاول مجدداً.');
        }
      },
    );

    if (!started && mounted) {
      setState(() => _isListening = false);
      await TtsNarrator.instance.speak('تعذّر تشغيل الميكروفون.');
    }
  }

  // ─── Capture dispatcher ───────────────────────────────────────────────────
  Future<void> _onCapture() async {
    if (_activeMode == _AppMode.color) {
      await _captureAndDetectColor();
    } else if (_activeMode == _AppMode.text) {
    await _captureAndExtractText();
    } else {
      await _captureAndSend();
    }
  }

  // ─── Local color detection ────────────────────────────────────────────────
  Future<void> _captureAndDetectColor() async {
    if (_isProcessing) return;
    setState(() { _isProcessing = true; _showSilentInput = false; });
    _resultFadeController.reverse();
    HapticFeedback.heavyImpact();

    try {
      final XFile file = await _controller!.takePicture();
      await TtsNarrator.instance.speak('جاري كشف اللون');

      final bytes = await File(file.path).readAsBytes();
      final frame = await compute(_decodeImageBytes, bytes);
      if (frame == null) {
        await TtsNarrator.instance.speak('تعذّر تحليل الصورة');
        return;
      }

      await _colorDetector.setFrame(frame);
      final result = _colorDetector.detect(0, 0, frame.width, frame.height);

      setState(() => _lastResult = result.colorAr);
      _resultFadeController.forward();
      await TtsNarrator.instance.speak('اللون ${result.colorAr}');
    } catch (_) {
      await TtsNarrator.instance.speak('خطأ في كشف اللون');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ─── Local text extraction ────────────────────────────────────────────────
  Future<void> _captureAndExtractText() async {
    if (_isProcessing) return;
    setState(() { 
      _isProcessing = true; 
      _showSilentInput = false; 
    });
    _resultFadeController.reverse();
    HapticFeedback.heavyImpact();

    try {
      final XFile file = await _controller!.takePicture();
      await TtsNarrator.instance.speak('جاري قراءة النص');

      final bytes = await File(file.path).readAsBytes();
      
      // Decode the image first (exactly like color detection)
      final frame = await compute(_decodeImageBytes, bytes);
      if (frame == null) {
        await TtsNarrator.instance.speak('تعذّر تحليل الصورة');
        return;
      }

      // Pass the decoded image directly to extractText
      final text = await TextExtractor.extractText(frame);
      
      if (text.isEmpty) {
        await TtsNarrator.instance.speak('لم يتم العثور على نص');
        setState(() => _lastResult = 'لم يتم العثور على نص');
      } else {
        setState(() => _lastResult = text);
        _resultFadeController.forward();
        await TtsNarrator.instance.speak(text);
      }
    } catch (e) {
      print('OCR Error: $e');
      await TtsNarrator.instance.speak('حدث خطأ في قراءة النص');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ─── Capture ─────────────────────────────────────────────────────────────
  Future<void> _captureAndSend() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _showSilentInput = false;
    });
    _resultFadeController.reverse();

    HapticFeedback.heavyImpact();
    await TtsNarrator.instance.speak('جاري التحليل');

    final XFile file = await _controller!.takePicture();
    await _sendImageToBackend(file.path, _lastCommand);

    setState(() => _isProcessing = false);
  }

  Future<void> _sendImageToBackend(String imagePath, String command) async {
    try {
      final uri = Uri.parse('$_baseUri$_analyzeEndpoint');
      final request = http.MultipartRequest('POST', uri)
        ..fields['command'] = command
        ..files.add(await http.MultipartFile.fromPath('file', imagePath));

      final response =
          await request.send().timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final json = jsonDecode(body);
        final description = json['description'] as String;

        setState(() => _lastResult = description);
        _resultFadeController.forward();
        await TtsNarrator.instance.speak(description);
      } else {
        await TtsNarrator.instance.speak('فشل التحليل');
      }
    } catch (_) {
      await TtsNarrator.instance.speak('خطأ في الاتصال');
    }
  }

  // ─── Silent input submit ──────────────────────────────────────────────────
  Future<void> _submitSilentInput() async {
    final text = _silentInputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _lastCommand = text;
      _showSilentInput = false;
    });
    _silentInputCtrl.clear();
    await TtsNarrator.instance.speak('تم: $text. اضغط مطولاً للتحليل.');
  }

  // ─── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const _LoadingScreen();
    }

    return Scaffold(
      backgroundColor: _kBlack,
      body: Stack(
        children: [
          // ── Camera feed ──────────────────────────────────────────────
          Positioned.fill(child: _CameraBackground(controller: _controller!)),

          // ── Dark vignette overlay ────────────────────────────────────
          Positioned.fill(child: _VignetteOverlay()),

          // ── Viewfinder frame ─────────────────────────────────────────
          Positioned.fill(
            child: _ViewfinderFrame(
              isProcessing: _isProcessing,
              scanLineAnim: _scanLineAnim,
              pulseAnim: _pulseAnim,
            ),
          ),

          // ── Top mode bar ─────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopModeBar(
              activeMode: _activeMode,
              onModeSelected: _switchMode,
            ),
          ),

          // ── Bottom panel ─────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomPanel(
              isListening: _isListening,
              isProcessing: _isProcessing,
              lastResult: _lastResult,
              resultFadeAnim: _resultFadeAnim,
              onListen: _startListening,
              onCapture: _onCapture,
            ),
          ),

          // ── Full-screen invisible gesture layer ──────────────────────
          Positioned.fill(
            child: Semantics(
              label: 'منطقة الكاميرا. انقر مرتين للتحدث. اضغط مطولاً للمسح. امسح لتغيير الوضع.',
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onDoubleTap: _startListening,
                onLongPress: _onCapture,
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity == null) return;
                  final modes = _AppMode.values;
                  final idx = modes.indexOf(_activeMode);
                  if (details.primaryVelocity! < -300 && idx < modes.length - 1) {
                    _switchMode(modes[idx + 1]);
                  } else if (details.primaryVelocity! > 300 && idx > 0) {
                    _switchMode(modes[idx - 1]);
                  }
                },
              ),
            ),
          ),

          // ── Mode change overlay ──────────────────────────────────────
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _modeOverlayVisible ? 1.0 : 0.0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xEE152E3E),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Text(
                    _modeOverlayLabel,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      color: Color(0xFFF7F5F0),
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Processing overlay ───────────────────────────────────────
          if (_isProcessing) const _ProcessingOverlay(),

          // ── Silent text-input panel ──────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              offset: _showSilentInput ? Offset.zero : const Offset(0, 1),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _showSilentInput ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_showSilentInput,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xCC152E3E),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _silentInputCtrl,
                                    textDirection: TextDirection.rtl,
                                    autofocus: _showSilentInput,
                                    style: const TextStyle(color: Color(0xFFF7F5F0)),
                                    decoration: const InputDecoration(
                                      hintText: 'اكتب أمرك هنا...',
                                      hintStyle: TextStyle(color: Color(0x80F7F5F0)),
                                      border: InputBorder.none,
                                    ),
                                    onSubmitted: (_) => _submitSilentInput(),
                                  ),
                                ),
                                Semantics(
                                  label: 'إرسال',
                                  button: true,
                                  child: IconButton(
                                    icon: const Icon(Icons.send_rounded, color: Color(0xFF2D6A8E)),
                                    onPressed: _submitSilentInput,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanLineController.dispose();
    _resultFadeController.dispose();
    _modeOverlayTimer?.cancel();
    _silentInputCtrl.dispose();
    _controller?.dispose();
    _speech.stop();
    TtsNarrator.instance.stop();
    super.dispose();
  }
}

// ─── App modes ────────────────────────────────────────────────────────────────
enum _AppMode {
  detect('كشف', 'وضع الكشف', 'كشف'),
  text('نص', 'وضع قراءة النص', 'نص'),
  distance('مسافة', 'وضع قياس المسافة', 'مسافة'),
  color('لون', 'وضع كشف اللون', 'لون');

  const _AppMode(this.label, this.announcementAr, this.defaultCommand);
  final String label;
  final String announcementAr;
  final String defaultCommand;
}

// ─── Loading screen ───────────────────────────────────────────────────────────
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _kBlack,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _kSteel, strokeWidth: 3),
            SizedBox(height: 20),
            Text(
              'جاري التهيئة...',
              style: TextStyle(
                color: _kTextMuted,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Camera background ────────────────────────────────────────────────────────
class _CameraBackground extends StatelessWidget {
  const _CameraBackground({required this.controller});
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.previewSize!.height,
          height: controller.value.previewSize!.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

// ─── Vignette ─────────────────────────────────────────────────────────────────
class _VignetteOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Colors.transparent, Color(0xAA000000)],
          ),
        ),
      ),
    );
  }
}

// ─── Viewfinder ───────────────────────────────────────────────────────────────
class _ViewfinderFrame extends StatelessWidget {
  const _ViewfinderFrame({
    required this.isProcessing,
    required this.scanLineAnim,
    required this.pulseAnim,
  });

  final bool isProcessing;
  final Animation<double> scanLineAnim;
  final Animation<double> pulseAnim;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: Listenable.merge([scanLineAnim, pulseAnim]),
        builder: (context, _) {
          return CustomPaint(
            painter: _ViewfinderPainter(
              isProcessing: isProcessing,
              scanProgress: scanLineAnim.value,
              pulse: pulseAnim.value,
            ),
          );
        },
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  _ViewfinderPainter({
    required this.isProcessing,
    required this.scanProgress,
    required this.pulse,
  });

  final bool isProcessing;
  final double scanProgress;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final frameW = size.width * 0.72;
    final frameH = size.height * 0.42;
    final left = cx - frameW / 2;
    final top = cy - frameH / 2;
    final right = cx + frameW / 2;
    final bottom = cy + frameH / 2;
    const cornerLen = 28.0;
    const cornerRadius = 5.0;

    final cornerColor = isProcessing
        ? _kSteel.withValues(alpha:0.9)
        : _kSteel.withValues(alpha:0.75 * pulse + 0.25);
    final cornerPaint = Paint()
      ..color = cornerColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(Offset(left + cornerRadius, top), Offset(left + cornerLen, top), cornerPaint);
    canvas.drawLine(Offset(left, top + cornerRadius), Offset(left, top + cornerLen), cornerPaint);
    // Top-right
    canvas.drawLine(Offset(right - cornerLen, top), Offset(right - cornerRadius, top), cornerPaint);
    canvas.drawLine(Offset(right, top + cornerRadius), Offset(right, top + cornerLen), cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(left, bottom - cornerLen), Offset(left, bottom - cornerRadius), cornerPaint);
    canvas.drawLine(Offset(left + cornerRadius, bottom), Offset(left + cornerLen, bottom), cornerPaint);
    // Bottom-right
    canvas.drawLine(Offset(right, bottom - cornerLen), Offset(right, bottom - cornerRadius), cornerPaint);
    canvas.drawLine(Offset(right - cornerLen, bottom), Offset(right - cornerRadius, bottom), cornerPaint);

    if (isProcessing) {
      final scanY = top + (bottom - top) * scanProgress;
      final scanPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            _kSteel.withValues(alpha:0.7),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTRB(left, scanY, right, scanY + 2));
      canvas.drawRect(Rect.fromLTRB(left, scanY, right, scanY + 2), scanPaint);
    }
  }

  @override
  bool shouldRepaint(_ViewfinderPainter old) =>
      old.scanProgress != scanProgress ||
      old.pulse != pulse ||
      old.isProcessing != isProcessing;
}

// ─── Top mode bar ─────────────────────────────────────────────────────────────
class _TopModeBar extends StatelessWidget {
  const _TopModeBar({
    required this.activeMode,
    required this.onModeSelected,
  });

  final _AppMode activeMode;
  final ValueChanged<_AppMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Colors.transparent],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _AppMode.values.map((mode) {
          final isActive = mode == activeMode;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Semantics(
              label: mode.announcementAr,
              selected: isActive,
              button: true,
              child: GestureDetector(
                onTap: () => onModeSelected(mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: isActive
                        ? _kSteel.withValues(alpha:0.18)
                        : Colors.white.withValues(alpha:0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isActive ? _kSteel.withValues(alpha:0.6) : _kBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    mode.label,
                    style: TextStyle(
                      color: isActive ? _kSteel : _kTextMuted,
                      fontSize: 15,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Bottom panel ─────────────────────────────────────────────────────────────
class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.isListening,
    required this.isProcessing,
    required this.lastResult,
    required this.resultFadeAnim,
    required this.onListen,
    required this.onCapture,
  });

  final bool isListening;
  final bool isProcessing;
  final String lastResult;
  final Animation<double> resultFadeAnim;
  final VoidCallback onListen;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding + 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xEE000000), Colors.transparent],
          stops: [0.0, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StateHintChip(isListening: isListening, isProcessing: isProcessing),
          const SizedBox(height: 10),
          if (lastResult.isNotEmpty)
            FadeTransition(
              opacity: resultFadeAnim,
              child: _ResultBox(text: lastResult),
            ),
          if (lastResult.isNotEmpty) const SizedBox(height: 10),
          _ActionButtons(
            isListening: isListening,
            isProcessing: isProcessing,
            onListen: onListen,
            onCapture: onCapture,
          ),
        ],
      ),
    );
  }
}

// ─── State hint ───────────────────────────────────────────────────────────────
class _StateHintChip extends StatelessWidget {
  const _StateHintChip({required this.isListening, required this.isProcessing});

  final bool isListening;
  final bool isProcessing;

  String get _text {
    if (isProcessing) return 'جاري التحليل...';
    if (isListening) return 'أستمع إليك...';
    return 'انقر مرتين للكلام  ·  اضغط مطولاً للمسح';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: isListening ? _kSteel.withValues(alpha:0.15) : _kSurfaceDim,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isListening ? _kSteel.withValues(alpha:0.5) : _kBorder,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isListening || isProcessing) ...[
            _PulsingDot(color: isListening ? _kSteel : _kWhite),
            const SizedBox(width: 8),
          ],
          Text(
            _text,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: isListening ? _kSteel : _kTextMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha:_anim.value),
        ),
      ),
    );
  }
}

// ─── Result box ───────────────────────────────────────────────────────────────
class _ResultBox extends StatelessWidget {
  const _ResultBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'آخر نتيجة: $text',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'آخر نتيجة',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: _kTextMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              text,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: _kWhite,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Action buttons ───────────────────────────────────────────────────────────
class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.isListening,
    required this.isProcessing,
    required this.onListen,
    required this.onCapture,
  });

  final bool isListening;
  final bool isProcessing;
  final VoidCallback onListen;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          label: 'تكلم. انقر مرتين على الشاشة للتفعيل.',
          button: true,
          child: _OutlineButton(
            onTap: onListen,
            isActive: isListening,
            activeColor: _kSteel,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isListening ? Icons.mic : Icons.mic_none_rounded,
                  color: isListening ? _kSteel : _kTextMuted,
                  size: 26,
                ),
                const SizedBox(height: 4),
                Text(
                  'تكلم',
                  style: TextStyle(
                    color: isListening ? _kSteel : _kTextMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'double tap',
                  style: TextStyle(color: Color(0x55FFFFFF), fontSize: 10),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: Semantics(
            label: 'تحليل المحيط. اضغط مطولاً على الشاشة للتفعيل.',
            button: true,
            child: GestureDetector(
              onTap: onCapture,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isProcessing ? _kSteel.withValues(alpha:0.7) : _kSteel,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isProcessing
                          ? Icons.hourglass_top_rounded
                          : Icons.document_scanner_rounded,
                      color: _kBlack,
                      size: 28,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isProcessing ? 'جاري التحليل...' : 'تحليل المحيط',
                      style: const TextStyle(
                        color: _kBlack,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'hold to scan',
                      style: TextStyle(color: Color(0x88000000), fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.child,
    required this.onTap,
    required this.isActive,
    required this.activeColor,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool isActive;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha:0.12)
              : Colors.white.withValues(alpha:0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? activeColor.withValues(alpha:0.6) : _kBorder,
            width: 1.5,
          ),
        ),
        child: child,
      ),
    );
  }
}

// ─── Processing overlay ───────────────────────────────────────────────────────
class _ProcessingOverlay extends StatelessWidget {
  const _ProcessingOverlay();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(color: Colors.transparent),
      ),
    );
  }
}
