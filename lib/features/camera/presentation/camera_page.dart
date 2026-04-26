// lib/features/camera/presentation/camera_page.dart
//
// Redesigned to match the Screen_Ready mockup:
//   • Navy #152E3E / Steel #2D6A8E / Cream #F7F5F0 palette
//   • LIVE + greeting chips in the top bar
//   • Scene caption overlay below top bar (shows last analysis result)
//   • Centered mic FAB with pulsing rings
//   • Describe / Read text / Call helper shortcut chips at the bottom
//
// All analysis logic (CameraService, STT, TTS, AnalysisService) is unchanged.

import 'dart:io';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../../analysis/domain/analysis_result.dart';
import '../../analysis/application/analysis_service.dart';
import '../../color_recognition/application/color_detector.dart';
import '../../../core/command_router.dart';
import '../../../core/services/stt_service.dart';
import '../../../core/services/tts_service.dart';
import '../application/camera_service.dart';

// Top-level decode so compute() can ship it to a background isolate.
img.Image? _decodeImageBytes(Uint8List bytes) => img.decodeImage(bytes);

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kNavy       = Color(0xFF152E3E);
const _kSteel      = Color(0xFF2D6A8E);
const _kCream      = Color(0xFFF7F5F0);
const _kSurface    = Color(0xCC0A1822);   // dark navy translucent
const _kBorder     = Color(0x1FF7F5F0);   // cream 12%
const _kTextMuted  = Color(0x99F7F5F0);   // cream 60%

// ─── Entry point ──────────────────────────────────────────────────────────────
class LiveCameraPage extends StatefulWidget {
  const LiveCameraPage({super.key});

  @override
  State<LiveCameraPage> createState() => _LiveCameraPageState();
}

class _LiveCameraPageState extends State<LiveCameraPage>
    with TickerProviderStateMixin {

  // ── Services ─────────────────────────────────────────────────────────────
  final _cameraService   = CameraService();
  final _sttService      = STTService();
  final _ttsService      = TTSService();
  final _analysisService = AnalysisService();
  final _colorDetector   = ColorDetector();

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isListening    = false;
  bool _isProcessing   = false;
  String _lastCommand  = 'كشف';
  String _lastResult   = '';
  String? _initError;
  _AppMode _activeMode = _AppMode.detect;

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _scanLineController;
  late AnimationController _resultFadeController;
  late AnimationController _pulseController;
  late Animation<double>   _scanLineAnim;
  late Animation<double>   _resultFadeAnim;
  late Animation<double>   _pulseAnim;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeEverything();
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _resultFadeController.dispose();
    _pulseController.dispose();
    _cameraService.dispose();
    _sttService.stopListening();
    _ttsService.stop();
    super.dispose();
  }

  void _setupAnimations() {
    _scanLineController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _scanLineAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.linear),
    );

    _resultFadeController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 400),
    );
    _resultFadeAnim = CurvedAnimation(
      parent: _resultFadeController,
      curve:  Curves.easeOut,
    );

    _pulseController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeEverything() async {
    try {
      await _cameraService.initialize();
      await _sttService.init();
      await _ttsService.init();
      if (!mounted) return;
      setState(() {});
      await _ttsService.speak('جاهز. اضغط مطولاً للمسح. انقر مرتين للكلام.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _initError = e.toString());
    }
  }

  // ─── Mode switch ───────────────────────────────────────────────────────────

  Future<void> _switchMode(_AppMode mode) async {
    if (_activeMode == mode) return;
    HapticFeedback.selectionClick();
    setState(() {
      _activeMode  = mode;
      _lastCommand = mode.defaultCommand;
    });
    await _ttsService.speak(mode.announcementAr);
  }

  // ─── STT ───────────────────────────────────────────────────────────────────

  Future<void> _startListening() async {
    if (_isListening || _isProcessing) return;
    HapticFeedback.mediumImpact();
    // TTS blocks until utterance finishes (awaitSpeakCompletion=true), then
    // a short gap ensures the microphone doesn't pick up TTS audio tail.
    await _ttsService.speak('أستمع إليك');
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() => _isListening = true);

    await _sttService.startListening((text) {
      setState(() {
        _lastCommand = text;
        _isListening = false;
      });
      _dispatchCommand(CommandRouter.route(text));
    });
  }

  // ─── Capture & Analyse ─────────────────────────────────────────────────────

  Future<void> _captureAndSend() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    _resultFadeController.reverse();
    HapticFeedback.heavyImpact();

    try {
      final XFile file = await _cameraService.takePicture();
      unawaited(_ttsService.speak('جاري التحليل'));

      final AnalysisResult result = await _analysisService.analyze(
        imagePath: file.path,
        command:   _lastCommand,
      );

      setState(() {
        _lastResult = result.description;
      });
      _resultFadeController.forward();
      await _ttsService.speak(result.description);

    } on AnalysisException {
      await _ttsService.speak('فشل التحليل');
    } catch (_) {
      await _ttsService.speak('خطأ في الاتصال');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ─── Color detection (local — no backend call) ──────────────────────────────

  Future<void> _captureAndDetectColor() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    _resultFadeController.reverse();
    HapticFeedback.heavyImpact();

    try {
      final file  = await _cameraService.takePicture();
      unawaited(_ttsService.speak('جاري كشف اللون'));

      final bytes = await File(file.path).readAsBytes();
      final frame = await compute(_decodeImageBytes, bytes);
      if (frame == null) {
        await _ttsService.speak('تعذّر تحليل الصورة');
        return;
      }

      await _colorDetector.setFrame(frame);
      final result = _colorDetector.detect(0, 0, frame.width, frame.height);

      setState(() => _lastResult = result.colorAr);
      _resultFadeController.forward();
      await _ttsService.speak('اللون ${result.colorAr}');

    } catch (_) {
      await _ttsService.speak('خطأ في كشف اللون');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ─── Command dispatch ───────────────────────────────────────────────────────

  void _dispatchCommand(AppCommand cmd) {
    switch (cmd) {
      case AppCommand.detectColor:
        _captureAndDetectColor();
      case AppCommand.readText:
        _switchMode(_AppMode.text).then((_) => _captureAndSend());
      case AppCommand.estimateDistance:
        setState(() {
          _activeMode  = _AppMode.detect;
          _lastCommand = 'تقدير المسافة';
        });
        _captureAndSend();
      case AppCommand.describe:
        _switchMode(_AppMode.detect).then((_) => _captureAndSend());
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return _ErrorScreen(
        message: _initError!,
        onRetry: () {
          setState(() => _initError = null);
          _initializeEverything();
        },
      );
    }
    if (!_cameraService.isReady) {
      return const _LoadingScreen();
    }

    return Scaffold(
      backgroundColor: _kNavy,
      body: Stack(
        children: [
          // Camera feed
          Positioned.fill(
            child: _CameraBackground(controller: _cameraService.controller!),
          ),

          // Dark gradient overlay (bottom-heavy, like the design)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin:  Alignment.topCenter,
                  end:    Alignment.bottomCenter,
                  stops:  const [0.0, 0.4, 1.0],
                  colors: [
                    const Color(0x330A1822),
                    Colors.transparent,
                    const Color(0xEB0A1822),
                  ],
                ),
              ),
            ),
          ),

          // Viewfinder corners + scan line
          Positioned.fill(
            child: _ViewfinderFrame(
              isProcessing: _isProcessing,
              scanLineAnim: _scanLineAnim,
            ),
          ),

          // Top bar: LIVE chip + greeting
          Positioned(
            top: 0, left: 0, right: 0,
            child: _TopBar(isProcessing: _isProcessing),
          ),

          // Scene caption (result overlay)
          if (_lastResult.isNotEmpty)
            Positioned(
              top:   MediaQuery.of(context).padding.top + 72,
              left:  16,
              right: 16,
              child: FadeTransition(
                opacity: _resultFadeAnim,
                child:   _SceneCaption(text: _lastResult),
              ),
            ),

          // Bottom panel
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _BottomPanel(
              isListening:  _isListening,
              isProcessing: _isProcessing,
              pulseAnim:    _pulseAnim,
              onMicTap:     _startListening,
              onMicHold:    _captureAndSend,
              onDescribe: () async {
                await _switchMode(_AppMode.detect);
                _captureAndSend();
              },
              onReadText: () async {
                await _switchMode(_AppMode.text);
                _captureAndSend();
              },
              onColors: _captureAndDetectColor,
            ),
          ),

          // Full-screen gesture layer (double-tap = speak, long-press = scan)
          Positioned.fill(
            child: Semantics(
              label: 'منطقة الكاميرا. انقر مرتين للتحدث. اضغط مطولاً للمسح.',
              child: GestureDetector(
                behavior:    HitTestBehavior.translucent,
                onDoubleTap: _startListening,
                onLongPress: _captureAndSend,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── App modes ────────────────────────────────────────────────────────────────
enum _AppMode {
  detect('كشف', 'وضع الكشف',      'كشف'),
  text  ('نص',  'وضع قراءة النص', 'نص');

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
      backgroundColor: _kNavy,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _kSteel, strokeWidth: 3),
            SizedBox(height: 20),
            Text(
              'جاري التهيئة...',
              style: TextStyle(
                color:      _kTextMuted,
                fontSize:   18,
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

// ─── Error screen ─────────────────────────────────────────────────────────────
class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.message, required this.onRetry});
  final String       message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kNavy,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined, color: _kTextMuted, size: 48),
              const SizedBox(height: 20),
              const Text(
                'Camera unavailable',
                style: TextStyle(
                  color:      _kCream,
                  fontSize:   20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Make sure Camera and Microphone permissions are granted in Settings.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _kTextMuted, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(
                    color:        _kSteel,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      color:      _kCream,
                      fontSize:   16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
          width:  controller.value.previewSize!.height,
          height: controller.value.previewSize!.width,
          child:  CameraPreview(controller),
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
  });

  final bool              isProcessing;
  final Animation<double> scanLineAnim;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: scanLineAnim,
        builder: (context, _) => CustomPaint(
          painter: _ViewfinderPainter(
            isProcessing: isProcessing,
            scanProgress: scanLineAnim.value,
          ),
        ),
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  _ViewfinderPainter({required this.isProcessing, required this.scanProgress});

  final bool   isProcessing;
  final double scanProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx     = size.width  / 2;
    final cy     = size.height / 2;
    final frameW = size.width  * 0.72;
    final frameH = size.height * 0.42;
    final left   = cx - frameW / 2;
    final top    = cy - frameH / 2 - size.height * 0.05;
    final right  = cx + frameW / 2;
    final bottom = cy + frameH / 2 - size.height * 0.05;

    const cornerLen    = 22.0;
    const cornerRadius = 4.0;

    final cornerPaint = Paint()
      ..color      = _kCream.withValues(alpha: 0.7)
      ..strokeWidth = 2.0
      ..style      = PaintingStyle.stroke
      ..strokeCap  = StrokeCap.round;

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
      final scanY     = top + (bottom - top) * scanProgress;
      final scanPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            _kSteel.withValues(alpha: 0.7),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTRB(left, scanY, right, scanY + 2));
      canvas.drawRect(Rect.fromLTRB(left, scanY, right, scanY + 2), scanPaint);
    }
  }

  @override
  bool shouldRepaint(_ViewfinderPainter old) =>
      old.scanProgress != scanProgress ||
      old.isProcessing != isProcessing;
}

// ─── Top bar ──────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({required this.isProcessing});
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 0),
      child: Row(
        children: [
          // LIVE chip
          _PillChip(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width:  8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFE45858),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isProcessing ? 'SCANNING' : 'LIVE',
                  style: const TextStyle(
                    color:         _kCream,
                    fontSize:      12,
                    fontWeight:    FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Greeting chip
          const _PillChip(
            child: Text(
              'Baseer',
              style: TextStyle(
                color:      _kCream,
                fontSize:   12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  const _PillChip({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color:        _kSurface,
            borderRadius: BorderRadius.circular(100),
            border:       Border.all(color: _kBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── Scene caption ────────────────────────────────────────────────────────────
class _SceneCaption extends StatelessWidget {
  const _SceneCaption({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color:        _kSurface,
            borderRadius: BorderRadius.circular(14),
            border:       Border.all(color: _kBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width:  24,
                height: 24,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kSteel,
                ),
                alignment: Alignment.center,
                child: const Text(
                  'B',
                  style: TextStyle(
                    color:      _kCream,
                    fontSize:   11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'I SEE',
                      style: TextStyle(
                        color:         _kTextMuted,
                        fontSize:      11,
                        fontWeight:    FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      text,
                      style: const TextStyle(
                        color:    _kCream,
                        fontSize: 14,
                        height:   1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bottom panel ─────────────────────────────────────────────────────────────
class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.isListening,
    required this.isProcessing,
    required this.pulseAnim,
    required this.onMicTap,
    required this.onMicHold,
    required this.onDescribe,
    required this.onReadText,
    required this.onColors,
  });

  final bool              isListening;
  final bool              isProcessing;
  final Animation<double> pulseAnim;
  final VoidCallback      onMicTap;
  final VoidCallback      onMicHold;
  final VoidCallback      onDescribe;
  final VoidCallback      onReadText;
  final VoidCallback      onColors;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 40, 20, bottomPad + 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.bottomCenter,
          end:    Alignment.topCenter,
          stops:  [0.0, 0.6, 1.0],
          colors: [Color(0xEB0A1822), Color(0xBB0A1822), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // State hint
          _StateHint(isListening: isListening, isProcessing: isProcessing),
          const SizedBox(height: 22),
          // Mic FAB
          _MicFab(
            isListening:  isListening,
            isProcessing: isProcessing,
            pulseAnim:    pulseAnim,
            onTap:        onMicTap,
            onHold:       onMicHold,
          ),
          const SizedBox(height: 22),
          // Shortcut chips
          Row(
            children: [
              _ShortcutChip(label: 'Describe',  onTap: onDescribe),
              const SizedBox(width: 10),
              _ShortcutChip(label: 'Read text', onTap: onReadText),
              const SizedBox(width: 10),
              _ShortcutChip(label: 'Colors',    onTap: onColors),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── State hint ───────────────────────────────────────────────────────────────
class _StateHint extends StatelessWidget {
  const _StateHint({required this.isListening, required this.isProcessing});
  final bool isListening;
  final bool isProcessing;

  String get _text {
    if (isProcessing) return 'جاري التحليل...';
    if (isListening)  return 'أستمع إليك...';
    return 'انقر مرتين للكلام  ·  اضغط مطولاً للمسح';
  }

  @override
  Widget build(BuildContext context) {
    final active = isListening || isProcessing;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color:        active
            ? _kSteel.withValues(alpha: 0.25)
            : _kSurface,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(
          color: active ? _kSteel.withValues(alpha: 0.5) : _kBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active) ...[
            _PulsingDot(color: isListening ? _kCream : _kSteel),
            const SizedBox(width: 8),
          ],
          Text(
            _text,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color:      active ? _kCream : _kTextMuted,
              fontSize:   13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mic FAB ──────────────────────────────────────────────────────────────────
class _MicFab extends StatelessWidget {
  const _MicFab({
    required this.isListening,
    required this.isProcessing,
    required this.pulseAnim,
    required this.onTap,
    required this.onHold,
  });

  final bool              isListening;
  final bool              isProcessing;
  final Animation<double> pulseAnim;
  final VoidCallback      onTap;
  final VoidCallback      onHold;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap:      onTap,
          onLongPress: onHold,
          child: AnimatedBuilder(
            animation: pulseAnim,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Outer pulse ring
                  Container(
                    width:  96 + 44,
                    height: 96 + 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kSteel.withValues(
                        alpha: 0.14 * pulseAnim.value,
                      ),
                    ),
                  ),
                  // Inner pulse ring
                  Container(
                    width:  96 + 20,
                    height: 96 + 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kSteel.withValues(
                        alpha: 0.28 * pulseAnim.value,
                      ),
                    ),
                  ),
                  child!,
                ],
              );
            },
            child: Container(
              width:  96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isProcessing
                    ? _kNavy.withValues(alpha: 0.85)
                    : _kSteel,
                boxShadow: [
                  BoxShadow(
                    color:      _kSteel.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: isProcessing
                  ? const Center(
                      child: SizedBox(
                        width:  28,
                        height: 28,
                        child:  CircularProgressIndicator(
                          color:       _kCream,
                          strokeWidth: 2.5,
                        ),
                      ),
                    )
                  : const Center(child: _MicShape()),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isListening ? 'أستمع...' : 'اضغط للتحدث',
          style: const TextStyle(
            color:      _kCream,
            fontSize:   15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          isListening ? 'اضغط للإيقاف' : 'اضغط مطولاً للتصوير',
          style: const TextStyle(color: _kTextMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class _MicShape extends StatelessWidget {
  const _MicShape();

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  18,
      height: 28,
      decoration: BoxDecoration(
        color:        _kCream,
        borderRadius: BorderRadius.circular(9),
      ),
    );
  }
}

// ─── Shortcut chip ────────────────────────────────────────────────────────────
class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({required this.label, required this.onTap});
  final String       label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color:        _kCream.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(
                  color: _kCream.withValues(alpha: 0.16),
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color:      _kCream,
                  fontSize:   13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Pulsing dot ──────────────────────────────────────────────────────────────
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
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
      builder: (_, child) => Container(
        width:  8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: _anim.value),
        ),
      ),
    );
  }
}

