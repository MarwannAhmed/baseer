import 'package:flutter/material.dart';
import '../../../core/app_settings.dart';
import '../../../core/services/tts_service.dart';

const _kNavy  = Color(0xFF152E3E);
const _kSteel = Color(0xFF2D6A8E);
const _kCream = Color(0xFFF7F5F0);
const _kInk   = Color(0xFF3C4B57);
const _kLine  = Color(0x1F152E3E);

// ── Language options (Arabic & English only) ──────────────────────────────────
const _langDisplay = ['العربية', 'English'];
const _langCodes   = ['ar', 'en'];

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  int get _selectedIndex => _langCodes.indexOf(AppSettings().locale).clamp(0, 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakIntro());
  }

  Future<void> _speakIntro() =>
      TTSService().speak(AppSettings().t(
        'أهلاً بك. بصير يصف العالم من حولك. اختر لغتك ثم اضغط ابدأ.',
        "Welcome. Baseer describes the world around you. Choose your language and tap Get started.",
      ));

  Future<void> _selectLang(int i) async {
    AppSettings().locale = _langCodes[i];
    setState(() {}); // rebuild labels
    // Re-init TTS with new language so subsequent pages speak in the right locale.
    await TTSService().init();
    await _speakIntro();
  }

  void _getStarted() {
    TTSService().stop();
    Navigator.pushNamed(context, '/permissions');
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings();
    return Scaffold(
      backgroundColor: _kCream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _EyeMark(size: 56),
              const SizedBox(height: 48),
              Text(
                s.t('أهلاً.', 'Welcome.'),
                style: const TextStyle(
                  color:         _kNavy,
                  fontSize:      40,
                  fontWeight:    FontWeight.w700,
                  letterSpacing: -1,
                  height:        1.05,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                s.t(
                  'بصير يصف العالم من حولك عبر كاميرا هاتفك وصوت بسيط.',
                  "Baseer describes the world around you through your phone's camera.",
                ),
                style: const TextStyle(color: _kInk, fontSize: 18, height: 1.45),
              ),
              const Spacer(),
              Text(
                s.t('اللغة', 'LANGUAGE'),
                style: const TextStyle(
                  color:         _kInk,
                  fontSize:      13,
                  letterSpacing: 0.8,
                  fontWeight:    FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: List.generate(_langDisplay.length, (i) {
                  final selected = i == _selectedIndex;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                      child: GestureDetector(
                        onTap: () => _selectLang(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color:        selected ? _kNavy : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: selected ? null : Border.all(color: _kLine, width: 1.5),
                          ),
                          child: Text(
                            _langDisplay[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color:      selected ? _kCream : _kNavy,
                              fontSize:   15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              _PrimaryButton(
                label: s.t('ابدأ', 'Get started'),
                onTap: _getStarted,
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  s.t('لدي حساب بالفعل', 'I already have an account'),
                  style: const TextStyle(color: _kInk, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});
  final String       label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(color: _kNavy, borderRadius: BorderRadius.circular(14)),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _kCream, fontSize: 18, fontWeight: FontWeight.w600),
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
        ..color = _kNavy ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05 ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(Offset(cx, cy), w * 0.117, Paint()..color = _kSteel);
    canvas.drawCircle(Offset(cx, cy), w * 0.042, Paint()..color = _kNavy);
    canvas.drawCircle(Offset(cx + w * 0.042, cy - w * 0.042), w * 0.017, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
