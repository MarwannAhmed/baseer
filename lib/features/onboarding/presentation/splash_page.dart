import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/tts_service.dart';

const _kNavy  = Color(0xFF152E3E);
const _kSteel = Color(0xFF2D6A8E);
const _kCream = Color(0xFFF7F5F0);

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    // Init TTS then speak — if the device has no TTS, the error is swallowed.
    TTSService().init().then((_) {
      if (mounted) TTSService().speak('مرحباً بك في بصير').catchError((_) {});
    }).catchError((_) {});

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) Navigator.pushReplacementNamed(context, '/welcome');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kNavy,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _EyeMark(size: 140),
            const SizedBox(height: 36),
            const Text(
              'Baseer',
              style: TextStyle(
                color:         _kCream,
                fontSize:      56,
                fontWeight:    FontWeight.w700,
                letterSpacing: -1.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your second pair of eyes',
              style: TextStyle(
                color:         _kCream.withValues(alpha: 0.7),
                fontSize:      16,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 80),
            const SizedBox(
              width: 44, height: 44,
              child: CircularProgressIndicator(color: _kSteel, strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}

class _EyeMark extends StatelessWidget {
  const _EyeMark({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size, size * 0.58), painter: _EyePainter());
}

class _EyePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final cx = w / 2;    final cy = h / 2;

    canvas.drawPath(
      Path()
        ..moveTo(w * 0.033, cy)
        ..quadraticBezierTo(cx, -h * 0.14, w * 0.967, cy)
        ..quadraticBezierTo(cx, h * 1.14, w * 0.033, cy),
      Paint()
        ..color = _kCream ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05 ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(Offset(cx, cy), w * 0.117, Paint()..color = _kSteel);
    canvas.drawCircle(Offset(cx, cy), w * 0.042, Paint()..color = _kNavy);
    canvas.drawCircle(Offset(cx + w * 0.042, cy - w * 0.042), w * 0.017, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
