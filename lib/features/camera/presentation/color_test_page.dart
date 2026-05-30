// lib/features/camera/presentation/color_test_page.dart
//
// Self-contained colour-detection test.
// Dependencies: camera, flutter_tts, image  (no backend, no STT, no HTTP).
//
// Gestures:
//   • Tap the yellow button  → capture + detect
//   • Long-press anywhere    → same

import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../../color_recognition/application/color_detector.dart';
import '../../../core/services/tts_service.dart';
import '../../camera/application/camera_service.dart';
// Top-level so compute() can ship it to a background isolate.
img.Image? _decodeImageBytes(Uint8List bytes) => img.decodeImage(bytes);

// ─── Visual colour swatches ───────────────────────────────────────────────────
const Map<String, Color> _swatches = {
  'red':    Color(0xFFE53935),
  'green':  Color(0xFF43A047),
  'blue':   Color(0xFF1E88E5),
  'yellow': Color(0xFFFDD835),
  'orange': Color(0xFFFB8C00),
  'brown':  Color(0xFF6D4C41),
  'purple': Color(0xFF8E24AA),
  'pink':   Color(0xFFEC407A),
  'white':  Color(0xFFF5F5F5),
  'gray':   Color(0xFF757575),
  'black':  Color(0xFF212121),
};

Color _swatch(String colorEn) => _swatches[colorEn] ?? Colors.grey;

// ─────────────────────────────────────────────────────────────────────────────

class ColorTestPage extends StatefulWidget {
  const ColorTestPage({super.key});

  @override
  State<ColorTestPage> createState() => _ColorTestPageState();
}

class _ColorTestPageState extends State<ColorTestPage> {
  final _camera        = CameraService();
  final _tts           = TTSService();
  final _colorDetector = ColorDetector();

  bool         _ready       = false;
  bool         _isScanning  = false;
  ColorResult? _lastResult;
  String       _statusText  = 'جاري التهيئة...';

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _camera.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _init() async {
    await _camera.initialize();
    await _tts.init();
    setState(() {
      _ready      = true;
      _statusText = 'اضغط للكشف عن اللون';
    });
    await _tts.speak('جاهز. اضغط للكشف عن اللون.');
  }

  // ── Detection ────────────────────────────────────────────────────────────

  Future<void> _scan() async {
    if (_isScanning || !_ready) return;
    setState(() {
      _isScanning = true;
      _statusText = 'جاري الكشف...';
    });
    HapticFeedback.heavyImpact();

    try {
      // 1. Capture
      final XFile    file  = await _camera.takePicture();
      final Uint8List bytes = await File(file.path).readAsBytes();

      // 2. Decode in background isolate (keeps UI smooth)
      final img.Image? frame = await compute(_decodeImageBytes, bytes);
      if (frame == null) {
        _onError('تعذّر تحليل الصورة');
        return;
      }

      // 3. Pre-process frame, then detect dominant colour for the full frame
      await _colorDetector.setFrame(frame);
      final ColorResult result =
          _colorDetector.detect(0, 0, frame.width, frame.height);

      // 4. Update UI + speak
      setState(() {
        _lastResult = result;
        _statusText = result.colorAr;
      });
      await _tts.speak('اللون ${result.colorAr}');

    } catch (e) {
      _onError('حدث خطأ');
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _onError(String message) {
    if (mounted) setState(() => _statusText = message);
    _tts.speak(message);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const _Loader();

    final controller = _camera.controller!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior:    HitTestBehavior.opaque,
        onLongPress: _scan,
        child: Stack(
          children: [
            // ── Camera preview ──────────────────────────────────────────
            Positioned.fill(
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width:  controller.value.previewSize!.height,
                    height: controller.value.previewSize!.width,
                    child:  CameraPreview(controller),
                  ),
                ),
              ),
            ),

            // ── Gradient scrim at the bottom ────────────────────────────
            const Positioned(
              bottom: 0, left: 0, right: 0, height: 260,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin:  Alignment.bottomCenter,
                    end:    Alignment.topCenter,
                    colors: [Color(0xF0000000), Colors.transparent],
                  ),
                ),
              ),
            ),

            // ── Result card ─────────────────────────────────────────────
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_lastResult != null) ...[
                        _ColorCard(result: _lastResult!),
                        const SizedBox(height: 16),
                      ],
                      _ScanButton(
                        isScanning:  _isScanning,
                        statusText:  _statusText,
                        onPressed:   _scan,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Colour result card ───────────────────────────────────────────────────────

class _ColorCard extends StatelessWidget {
  const _ColorCard({required this.result});
  final ColorResult result;

  @override
  Widget build(BuildContext context) {
    final color = _swatch(result.colorEn);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color:        const Color(0xCC000000),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withOpacity(0.5), width: 2),
      ),
      child: Row(
        children: [
          // Colour swatch circle
          Container(
            width:  56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color:      color.withOpacity(0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Names
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.colorAr,
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   28,
                    fontWeight: FontWeight.w700,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 2),
                Text(
                  result.colorEn,
                  style: const TextStyle(
                    color:    Color(0x99FFFFFF),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Scan button ──────────────────────────────────────────────────────────────

class _ScanButton extends StatelessWidget {
  const _ScanButton({
    required this.isScanning,
    required this.statusText,
    required this.onPressed,
  });

  final bool         isScanning;
  final String       statusText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color:        isScanning
              ? const Color(0xB3FFE14D)
              : const Color(0xFFFFE14D),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isScanning)
              const SizedBox(
                width:  20,
                height: 20,
                child:  CircularProgressIndicator(
                  color:       Colors.black,
                  strokeWidth: 2.5,
                ),
              )
            else
              const Icon(Icons.colorize_rounded, color: Colors.black, size: 24),
            const SizedBox(width: 10),
            Text(
              isScanning ? 'جاري الكشف...' : 'كشف اللون',
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                color:      Colors.black,
                fontSize:   17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Loading screen ───────────────────────────────────────────────────────────

class _Loader extends StatelessWidget {
  const _Loader();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color:       Color(0xFFFFE14D),
              strokeWidth: 3,
            ),
            SizedBox(height: 20),
            Text(
              'جاري التهيئة...',
              style: TextStyle(
                color:      Color(0x99FFFFFF),
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