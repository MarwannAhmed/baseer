// lib/features/camera/presentation/camera_page.dart
//
// Changes vs original:
//   • Uses CameraService, STTService, TTSService, AnalysisService — no more
//     inline duplicated logic.
//   • Wires ColorDetector for local, on-device color detection.
//   • TTS announcement fires in parallel with capture (no race condition).
//   • AnalysisResult (structured) is consumed; enriched DetectedObject list
//     is kept in state for future use (e.g. spatial audio, object list UI).
//   • try/finally guarantees _isProcessing is always reset.

import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../../color_recognition/application/color_detector.dart';
import '../../analysis/domain/analysis_result.dart';
import '../../analysis/application/analysis_service.dart';
import '../../analysis/domain/detected_object.dart';
import '../../../core/services/stt_service.dart';
import '../../../core/services/tts_service.dart';
import '../application/camera_service.dart';

// ─── Top-level isolate helper ─────────────────────────────────────────────────
// Must be a top-level function so compute() can send it to a background isolate.
img.Image? _decodeImageBytes(Uint8List bytes) => img.decodeImage(bytes);

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kYellow    = Color(0xFFFFE14D);
const _kWhite     = Colors.white;
const _kBlack     = Colors.black;
const _kSurface   = Color(0xCC000000);
const _kSurfaceDim = Color(0x99000000);
const _kBorder    = Color(0x33FFFFFF);
const _kTextMuted = Color(0x99FFFFFF);

// ─── Entry point ──────────────────────────────────────────────────────────────
class LiveCameraPage extends StatefulWidget {
  const LiveCameraPage({super.key});

  @override
  State<LiveCameraPage> createState() => _LiveCameraPageState();
}

class _LiveCameraPageState extends State<LiveCameraPage>
    with TickerProviderStateMixin {

  // ── Services (all owned here, not recreated inline) ──────────────────────
  final _cameraService   = CameraService();
  final _sttService      = STTService();
  final _ttsService      = TTSService();
  final _analysisService = AnalysisService();
  final _colorDetector   = ColorDetector();

  // ── State ────────────────────────────────────────────────────────────────
  bool _isListening    = false;
  bool _isProcessing   = false;
  String _lastCommand  = 'كشف';
  String _lastResult   = '';
  _AppMode _activeMode = _AppMode.detect;

  /// Enriched objects from the last detect-mode scan (local colors applied).
  List<DetectedObject> _detectedObjects = [];

  // ── Animations ───────────────────────────────────────────────────────────
  late AnimationController _pulseController;
  late AnimationController _scanLineController;
  late AnimationController _resultFadeController;
  late Animation<double>   _pulseAnim;
  late Animation<double>   _scanLineAnim;
  late Animation<double>   _resultFadeAnim;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeEverything();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanLineController.dispose();
    _resultFadeController.dispose();
    _cameraService.dispose();
    _sttService.stopListening();
    _ttsService.stop();
    super.dispose();
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

  // ─── Init ──────────────────────────────────────────────────────────────────

  Future<void> _initializeEverything() async {
    await _cameraService.initialize();
    await _sttService.init();
    await _ttsService.init();
    setState(() {});
    await _ttsService.speak('جاهز. اضغط مطولاً للمسح. انقر مرتين للكلام.');
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
    await _ttsService.speak('أستمع إليك');
    setState(() => _isListening = true);

    await _sttService.startListening((text) {
      setState(() {
        _lastCommand = text;
        _isListening = false;
      });
      // Fire-and-forget: confirm what was heard while we return to idle.
      _ttsService.speak('قلت: $text');
    });
  }

  // ─── Capture & Analyse ─────────────────────────────────────────────────────

  Future<void> _captureAndSend() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    _resultFadeController.reverse();
    HapticFeedback.heavyImpact();

    try {
      // 1. Capture the frame first — TTS runs in parallel, not before.
      final XFile file = await _cameraService.takePicture();
      // Announce analysis while the HTTP request is building (no blocking wait).
      unawaited(_ttsService.speak('جاري التحليل'));

      // 2. Backend: object detection + Arabic description.
      final AnalysisResult result = await _analysisService.analyze(
        imagePath: file.path,
        command:   _lastCommand,
      );

      // 3. Local color detection — only meaningful in detect mode with objects.
      List<DetectedObject> enrichedObjects = result.objects;
      if (_activeMode == _AppMode.detect && result.objects.isNotEmpty) {
        enrichedObjects = await _enrichWithLocalColors(file.path, result.objects);
      }

      // 4. Update UI and speak the backend description.
      setState(() {
        _lastResult      = result.description;
        _detectedObjects = enrichedObjects;
      });
      _resultFadeController.forward();
      await _ttsService.speak(result.description);

    } on AnalysisException {
      await _ttsService.speak('فشل التحليل');
    } catch (_) {
      await _ttsService.speak('خطأ في الاتصال');
    } finally {
      // Always release the processing lock.
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Decodes the captured image in a background isolate, then runs
  /// [ColorDetector.detectColorsForObjects] to override backend colors
  /// with locally computed ones.
  ///
  /// Falls back silently to the original [objects] list on any error.
  Future<List<DetectedObject>> _enrichWithLocalColors(
    String imagePath,
    List<DetectedObject> objects,
  ) async {
    try {
      final Uint8List bytes = await File(imagePath).readAsBytes();
      final img.Image? frame = await compute(_decodeImageBytes, bytes);
      if (frame == null) return objects;

      final rawMaps = objects.map(_objectToMap).toList();
      final enrichedMaps =
          await _colorDetector.detectColorsForObjects(frame, rawMaps);
      return enrichedMaps.map(DetectedObject.fromJson).toList();
    } catch (_) {
      // Color detection failed — return backend colors unchanged.
      return objects;
    }
  }

  /// Converts a [DetectedObject] to the dynamic map format expected by
  /// [ColorDetector.detectColorsForObjects].
  Map<String, dynamic> _objectToMap(DetectedObject obj) => {
    'label':       obj.label,
    'confidence':  obj.confidence,
    'bbox': <String, dynamic>{
      'x1': obj.bbox['x1'] ?? 0,
      'y1': obj.bbox['y1'] ?? 0,
      'x2': obj.bbox['x2'] ?? 0,
      'y2': obj.bbox['y2'] ?? 0,
    },
    'center':      <String, dynamic>{...obj.center},
    'size':        <String, dynamic>{...obj.size},
    'color_en':    obj.colorEn,
    'color_ar':    obj.colorAr,
    'distance_cm': obj.distanceCm,
  };

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_cameraService.isReady) {
      return const _LoadingScreen();
    }

    return Scaffold(
      backgroundColor: _kBlack,
      body: Stack(
        children: [
          // Camera feed
          Positioned.fill(
            child: _CameraBackground(controller: _cameraService.controller!),
          ),

          // Dark vignette overlay
          Positioned.fill(child: _VignetteOverlay()),

          // Viewfinder frame + scan-line
          Positioned.fill(
            child: _ViewfinderFrame(
              isProcessing: _isProcessing,
              scanLineAnim: _scanLineAnim,
              pulseAnim:    _pulseAnim,
            ),
          ),

          // Top mode bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: _TopModeBar(
              activeMode:     _activeMode,
              onModeSelected: _switchMode,
            ),
          ),

          // Bottom panel
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _BottomPanel(
              isListening:     _isListening,
              isProcessing:    _isProcessing,
              lastResult:      _lastResult,
              resultFadeAnim:  _resultFadeAnim,
              onListen:        _startListening,
              onCapture:       _captureAndSend,
            ),
          ),

          // Full-screen invisible gesture layer
          Positioned.fill(
            child: Semantics(
              label: 'منطقة الكاميرا. انقر مرتين للتحدث. اضغط مطولاً للمسح.',
              child: GestureDetector(
                behavior:     HitTestBehavior.translucent,
                onDoubleTap:  _startListening,
                onLongPress:  _captureAndSend,
              ),
            ),
          ),

          // Processing shimmer
          if (_isProcessing) const _ProcessingOverlay(),
        ],
      ),
    );
  }
}

// ─── App modes ────────────────────────────────────────────────────────────────
enum _AppMode {
  detect  ('كشف',   'وضع الكشف',           'كشف'),
  text    ('نص',    'وضع قراءة النص',       'نص'),
  distance('مسافة', 'وضع قياس المسافة',    'مسافة');

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
            CircularProgressIndicator(color: _kYellow, strokeWidth: 3),
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
          width:  controller.value.previewSize!.height,
          height: controller.value.previewSize!.width,
          child:  CameraPreview(controller),
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

  final bool             isProcessing;
  final Animation<double> scanLineAnim;
  final Animation<double> pulseAnim;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: Listenable.merge([scanLineAnim, pulseAnim]),
        builder: (context, _) => CustomPaint(
          painter: _ViewfinderPainter(
            isProcessing: isProcessing,
            scanProgress: scanLineAnim.value,
            pulse:        pulseAnim.value,
          ),
        ),
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

  final bool   isProcessing;
  final double scanProgress;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final cx     = size.width  / 2;
    final cy     = size.height / 2;
    final frameW = size.width  * 0.72;
    final frameH = size.height * 0.42;
    final left   = cx - frameW / 2;
    final top    = cy - frameH / 2;
    final right  = cx + frameW / 2;
    final bottom = cy + frameH / 2;
    const cornerLen    = 28.0;
    const cornerRadius = 5.0;

    final cornerColor = isProcessing
        ? _kYellow.withOpacity(0.9)
        : _kYellow.withOpacity(0.75 * pulse + 0.25);

    final cornerPaint = Paint()
      ..color      = cornerColor
      ..strokeWidth = 3.0
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
      final scanY    = top + (bottom - top) * scanProgress;
      final scanPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            _kYellow.withOpacity(0.7),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTRB(left, scanY, right, scanY + 2));
      canvas.drawRect(Rect.fromLTRB(left, scanY, right, scanY + 2), scanPaint);
    }
  }

  @override
  bool shouldRepaint(_ViewfinderPainter old) =>
      old.scanProgress != scanProgress ||
      old.pulse        != pulse        ||
      old.isProcessing != isProcessing;
}

// ─── Top mode bar ─────────────────────────────────────────────────────────────
class _TopModeBar extends StatelessWidget {
  const _TopModeBar({
    required this.activeMode,
    required this.onModeSelected,
  });

  final _AppMode                 activeMode;
  final ValueChanged<_AppMode>   onModeSelected;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topCenter,
          end:    Alignment.bottomCenter,
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
              label:    mode.announcementAr,
              selected: isActive,
              button:   true,
              child: GestureDetector(
                onTap: () => onModeSelected(mode),
                child: AnimatedContainer(
                  duration:  const Duration(milliseconds: 250),
                  curve:     Curves.easeOut,
                  padding:   const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: isActive
                        ? _kYellow.withOpacity(0.18)
                        : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isActive
                          ? _kYellow.withOpacity(0.6)
                          : _kBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    mode.label,
                    style: TextStyle(
                      color:      isActive ? _kYellow : _kTextMuted,
                      fontSize:   15,
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

  final bool             isListening;
  final bool             isProcessing;
  final String           lastResult;
  final Animation<double> resultFadeAnim;
  final VoidCallback     onListen;
  final VoidCallback     onCapture;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding + 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.bottomCenter,
          end:    Alignment.topCenter,
          colors: [Color(0xEE000000), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StateHintChip(
            isListening:  isListening,
            isProcessing: isProcessing,
          ),
          const SizedBox(height: 10),
          if (lastResult.isNotEmpty) ...[
            FadeTransition(
              opacity: resultFadeAnim,
              child:   _ResultBox(text: lastResult),
            ),
            const SizedBox(height: 10),
          ],
          _ActionButtons(
            isListening:  isListening,
            isProcessing: isProcessing,
            onListen:     onListen,
            onCapture:    onCapture,
          ),
        ],
      ),
    );
  }
}

// ─── State hint ───────────────────────────────────────────────────────────────
class _StateHintChip extends StatelessWidget {
  const _StateHintChip({
    required this.isListening,
    required this.isProcessing,
  });

  final bool isListening;
  final bool isProcessing;

  String get _text {
    if (isProcessing) return 'جاري التحليل...';
    if (isListening)  return 'أستمع إليك...';
    return 'انقر مرتين للكلام  ·  اضغط مطولاً للمسح';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: isListening ? _kYellow.withOpacity(0.15) : _kSurfaceDim,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isListening ? _kYellow.withOpacity(0.5) : _kBorder,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isListening || isProcessing) ...[
            _PulsingDot(color: isListening ? _kYellow : _kWhite),
            const SizedBox(width: 8),
          ],
          Text(
            _text,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color:      isListening ? _kYellow : _kTextMuted,
              fontSize:   13,
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
      builder: (_, __) => Container(
        width:  8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withOpacity(_anim.value),
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
          color:        _kSurface,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: _kBorder, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'آخر نتيجة',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color:         _kTextMuted,
                fontSize:      11,
                fontWeight:    FontWeight.w500,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              text,
              textDirection: TextDirection.rtl,
              textAlign:     TextAlign.right,
              style: const TextStyle(
                color:      _kWhite,
                fontSize:   17,
                fontWeight: FontWeight.w600,
                height:     1.4,
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

  final bool         isListening;
  final bool         isProcessing;
  final VoidCallback onListen;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Voice button
        Semantics(
          label:  'تكلم. انقر مرتين على الشاشة للتفعيل.',
          button: true,
          child: _OutlineButton(
            onTap:       onListen,
            isActive:    isListening,
            activeColor: _kYellow,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isListening ? Icons.mic : Icons.mic_none_rounded,
                  color: isListening ? _kYellow : _kTextMuted,
                  size:  26,
                ),
                const SizedBox(height: 4),
                Text(
                  'تكلم',
                  style: TextStyle(
                    color:      isListening ? _kYellow : _kTextMuted,
                    fontSize:   13,
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

        // Scan button — larger, yellow fill
        Expanded(
          flex: 2,
          child: Semantics(
            label:  'تحليل المحيط. اضغط مطولاً على الشاشة للتفعيل.',
            button: true,
            child: GestureDetector(
              onTap: onCapture,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isProcessing
                      ? _kYellow.withOpacity(0.7)
                      : _kYellow,
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
                      size:  28,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isProcessing ? 'جاري التحليل...' : 'تحليل المحيط',
                      style: const TextStyle(
                        color:      _kBlack,
                        fontSize:   15,
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

  final Widget       child;
  final VoidCallback onTap;
  final bool         isActive;
  final Color        activeColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withOpacity(0.12)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? activeColor.withOpacity(0.6) : _kBorder,
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