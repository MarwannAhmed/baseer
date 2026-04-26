import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/app_settings.dart';
import '../../../core/services/tts_service.dart';

const _kNavy  = Color(0xFF152E3E);
const _kSteel = Color(0xFF2D6A8E);
const _kCream = Color(0xFFF7F5F0);
const _kInk   = Color(0xFF3C4B57);
const _kLine  = Color(0x1F152E3E);

class VoiceSetupPage extends StatefulWidget {
  const VoiceSetupPage({super.key});

  @override
  State<VoiceSetupPage> createState() => _VoiceSetupPageState();
}

class _VoiceSetupPageState extends State<VoiceSetupPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakIntro());
  }

  @override
  void dispose() {
    _pulse.dispose();
    TTSService().stop();
    super.dispose();
  }

  Future<void> _speakIntro() => TTSService().speak(AppSettings().t(
    'الخطوة الثانية من ثلاثة. قل: مرحباً بصير، ماذا ترى؟ اضغط الميكروفون للبدء، أو تخطى الآن.',
    'Step 2 of 3. Say: Hey Baseer, what do you see? Tap the microphone to begin, or skip for now.',
  ));

  void _next() {
    TTSService().stop();
    Navigator.pushNamed(context, '/features');
  }

  // 28 bar heights derived from a sine pattern.
  static final List<double> _bars = List.generate(28, (i) {
    final h = 8 + (math.sin(i * 0.7).abs() * 38) + (i % 3) * 6.0;
    return h.clamp(0, 58);
  });

  @override
  Widget build(BuildContext context) {
    final s = AppSettings();
    return Scaffold(
      backgroundColor: _kCream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.t('الخطوة ٢ من ٣', 'STEP 2 OF 3'),
                style: const TextStyle(
                  color:         _kSteel,
                  fontSize:      13,
                  fontWeight:    FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.t('دعني أسمعك', 'Let me hear you'),
                style: const TextStyle(
                  color:         _kNavy,
                  fontSize:      32,
                  fontWeight:    FontWeight.w700,
                  letterSpacing: -0.5,
                  height:        1.1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                s.t(
                  'قل العبارة التالية حتى يتعرف بصير على صوتك.',
                  'Say the phrase below so Baseer learns your voice.',
                ),
                style: const TextStyle(color: _kInk, fontSize: 15, height: 1.45),
              ),
              const SizedBox(height: 28),
              // Phrase card
              Container(
                width:   double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
                decoration: BoxDecoration(
                  color:        Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border:       Border.all(color: _kLine),
                ),
                child: Column(
                  children: [
                    Text(
                      s.t('كرر معي', 'REPEAT AFTER ME'),
                      style: const TextStyle(
                        color:         _kInk,
                        fontSize:      12,
                        fontWeight:    FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.t(
                        '"مرحباً بصير، ماذا ترى؟"',
                        '"Hey Baseer, what do you see?"',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color:         _kNavy,
                        fontSize:      22,
                        fontWeight:    FontWeight.w600,
                        height:        1.3,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              // Waveform
              SizedBox(
                height: 70,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(_bars.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: Container(
                        width:      4,
                        height:     _bars[i],
                        decoration: BoxDecoration(
                          color:        i < 14 ? _kSteel : _kLine,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 12),
              // Mic button with pulsing ring
              Center(
                child: GestureDetector(
                  onTap: _next,
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, child) {
                      return Container(
                        width:  92 + 22,
                        height: 92 + 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kSteel.withValues(alpha: 0.18 * _pulse.value),
                        ),
                        child: child,
                      );
                    },
                    child: Center(
                      child: Container(
                        width:  92,
                        height: 92,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kNavy,
                        ),
                        child: const Center(child: _MicIcon()),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  s.t('أستمع... اضغط للإيقاف', 'Listening… tap to stop'),
                  style: const TextStyle(color: _kInk, fontSize: 14),
                ),
              ),
              const Spacer(),
              _GhostButton(
                label: s.t('تخطى الآن', 'Skip for now'),
                onTap: _next,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MicIcon extends StatelessWidget {
  const _MicIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  18,
      height: 28,
      decoration: BoxDecoration(
        color:        const Color(0xFFF7F5F0),
        borderRadius: BorderRadius.circular(9),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onTap});
  final String       label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: _kLine, width: 1.5),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color:      _kNavy,
            fontSize:   16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
