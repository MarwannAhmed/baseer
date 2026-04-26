import 'package:flutter/material.dart';
import '../../../core/app_settings.dart';
import '../../../core/services/tts_service.dart';

const _kNavy  = Color(0xFF152E3E);
const _kSteel = Color(0xFF2D6A8E);
const _kCream = Color(0xFFF7F5F0);
const _kInk   = Color(0xFF3C4B57);
const _kLine  = Color(0x1F152E3E);

// ── Bilingual feature data ─────────────────────────────────────────────────────

const _featuresEn = [
  (n: '1', title: 'Object Detection',    desc: "Aim your camera and I'll identify and name the objects around you."),
  (n: '2', title: 'Text Extraction',     desc: "Menus, signs, labels, handwriting — I'll read them all out loud."),
  (n: '3', title: 'Color Recognition',   desc: "Ask what color something is and I'll tell you instantly."),
  (n: '4', title: 'Distance Estimation', desc: "I'll tell you how close or far objects are from you."),
];

const _featuresAr = [
  (n: '١', title: 'التعرف على الأشياء', desc: 'وجّه كاميرتك وسأحدد لك الأشياء من حولك وأسميها.'),
  (n: '٢', title: 'استخراج النصوص',    desc: 'قوائم، لافتات، ملصقات، خط اليد — سأقرأها جميعاً بصوت عالٍ.'),
  (n: '٣', title: 'التعرف على الألوان', desc: 'اسألني عن لون أي شيء وسأجيبك فوراً.'),
  (n: '٤', title: 'تقدير المسافات',    desc: 'سأخبرك كم تبعد الأشياء عنك أو تقترب.'),
];

// ──────────────────────────────────────────────────────────────────────────────

class FeaturesPage extends StatefulWidget {
  const FeaturesPage({super.key});

  @override
  State<FeaturesPage> createState() => _FeaturesPageState();
}

class _FeaturesPageState extends State<FeaturesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakIntro());
  }

  @override
  void dispose() {
    TTSService().stop();
    super.dispose();
  }

  Future<void> _speakIntro() => TTSService().speak(AppSettings().t(
    'الخطوة الثالثة من ثلاثة. ما يمكنني فعله. '
    'أولاً: التعرف على الأشياء. '
    'ثانياً: استخراج النصوص. '
    'ثالثاً: التعرف على الألوان. '
    'رابعاً: تقدير المسافات. '
    'اضغط أنا مستعد.',
    'Step 3 of 3. What I can do: '
    'Object detection. '
    'Text extraction. '
    'Color recognition. '
    'Distance estimation. '
    "Tap I'm ready.",
  ));

  void _goToCamera() {
    TTSService().stop();
    Navigator.pushNamedAndRemoveUntil(context, '/camera', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final s        = AppSettings();
    final features = s.isAr ? _featuresAr : _featuresEn;
    return Scaffold(
      backgroundColor: _kCream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.t('الخطوة ٣ من ٣', 'STEP 3 OF 3'),
                style: const TextStyle(
                  color:         _kSteel,
                  fontSize:      13,
                  fontWeight:    FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.t('ما يمكنني فعله', 'What I can do'),
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
                  'وجّه أو اسأل أو اضغط للتصوير. سأصف لك بصوت عالٍ.',
                  "Point, ask, or hold to capture. I'll describe it out loud.",
                ),
                style: const TextStyle(color: _kInk, fontSize: 15, height: 1.45),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: features
                      .map((f) => _FeatureRow(n: f.n, title: f.title, desc: f.desc))
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),
              _PrimaryButton(
                label: s.t('أنا مستعد', "I'm ready"),
                onTap: _goToCamera,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Feature row ────────────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.n, required this.title, required this.desc});
  final String n;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:   const EdgeInsets.symmetric(vertical: 18),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: _kLine))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width:  40,
            height: 40,
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              border: Border.all(color: _kNavy, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              n,
              style: const TextStyle(
                color:      _kNavy,
                fontSize:   15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color:      _kNavy,
                      fontSize:   17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: const TextStyle(color: _kInk, fontSize: 14, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Primary button ─────────────────────────────────────────────────────────────

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
        decoration: BoxDecoration(
          color:        _kNavy,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color:      _kCream,
            fontSize:   18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
