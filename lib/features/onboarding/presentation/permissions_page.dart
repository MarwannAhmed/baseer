import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/app_settings.dart';
import '../../../core/services/tts_service.dart';

const _kNavy  = Color(0xFF152E3E);
const _kSteel = Color(0xFF2D6A8E);
const _kCream = Color(0xFFF7F5F0);
const _kInk   = Color(0xFF3C4B57);
const _kSoft  = Color(0xFFEDE8DE);
const _kLine  = Color(0x1F152E3E);

// ── Bilingual permission metadata ─────────────────────────────────────────────

const _labelsAr = {
  'Camera':        'كاميرا',
  'Microphone':    'ميكروفون',
  'Notifications': 'إشعارات',
  'Location':      'موقع',
};

const _descsEn = {
  'Camera':        'To see and describe scenes, text and objects.',
  'Microphone':    'So you can ask questions and give voice commands.',
  'Notifications': 'Gentle reminders, never sounds without your OK.',
  'Location':      'For nearby places, addresses and safe navigation.',
};
const _descsAr = {
  'Camera':        'لرؤية ووصف المشاهد والنصوص والأشياء.',
  'Microphone':    'لطرح الأسئلة وإعطاء الأوامر الصوتية.',
  'Notifications': 'تذكيرات لطيفة، لن نصدر أصواتاً دون موافقتك.',
  'Location':      'للأماكن القريبة والعناوين والملاحة الآمنة.',
};

// ──────────────────────────────────────────────────────────────────────────────

class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  final Map<String, bool> _toggles = {
    'Camera':        true,
    'Microphone':    true,
    'Notifications': true,
    'Location':      false,
  };

  static const _required = {'Camera', 'Microphone'};
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakIntro());
  }

  Future<void> _speakIntro() => TTSService().speak(AppSettings().t(
    'الخطوة الأولى من ثلاثة. نحتاج إذن الكاميرا والميكروفون للعمل. اضغط السماح والمتابعة.',
    'Step 1 of 3. We need Camera and Microphone access to work. Tap Allow and continue.',
  ));

  Future<void> _requestAndContinue() async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);

    final toRequest = <Permission>[
      Permission.camera,
      Permission.microphone,
      if (_toggles['Notifications'] == true) Permission.notification,
      if (_toggles['Location'] == true) Permission.location,
    ];

    final statuses = await toRequest.request();

    final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
    final micGranted    = statuses[Permission.microphone]?.isGranted ?? false;

    if (!mounted) return;
    setState(() => _isRequesting = false);

    if (!cameraGranted || !micGranted) {
      await TTSService().speak(AppSettings().t(
        'يتطلب بصير إذن الكاميرا والميكروفون. افتح الإعدادات لمنح الإذن.',
        'Baseer requires Camera and Microphone. Open Settings to grant permission.',
      ));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _kCream,
          title: Text(
            AppSettings().t('أذونات مطلوبة', 'Permissions required'),
            style: const TextStyle(color: _kNavy, fontWeight: FontWeight.w700),
          ),
          content: Text(
            AppSettings().t(
              'يتطلب بصير الوصول إلى الكاميرا والميكروفون. يرجى تفعيلهما في إعدادات الجهاز.',
              'Camera and Microphone are required for Baseer to work. Enable them in device Settings.',
            ),
            style: const TextStyle(color: _kInk),
          ),
          actions: [
            TextButton(
              onPressed: () { Navigator.of(ctx).pop(); openAppSettings(); },
              child: Text(AppSettings().t('فتح الإعدادات', 'Open Settings'),
                  style: const TextStyle(color: _kSteel)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(AppSettings().t('إلغاء', 'Cancel'),
                  style: const TextStyle(color: _kInk)),
            ),
          ],
        ),
      );
      return;
    }

    TTSService().stop();
    if (!mounted) return;
    Navigator.pushNamed(context, '/voice_setup');
  }

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
                s.t('الخطوة ١ من ٣', 'STEP 1 OF 3'),
                style: const TextStyle(
                  color: _kSteel, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.t('بعض الأذونات', 'A few permissions'),
                style: const TextStyle(
                  color: _kNavy, fontSize: 32, fontWeight: FontWeight.w700,
                  letterSpacing: -0.5, height: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                s.t(
                  'بصير يستخدم فقط ما يحتاجه لوصف محيطك.',
                  'Baseer only uses what it needs to describe your surroundings.',
                ),
                style: const TextStyle(color: _kInk, fontSize: 15, height: 1.45),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: _toggles.keys.map((key) {
                    final isRequired = _required.contains(key);
                    final label = s.isAr ? (_labelsAr[key] ?? key) : key;
                    final desc  = s.isAr ? (_descsAr[key]  ?? '') : (_descsEn[key] ?? '');
                    return _PermissionRow(
                      label:    label,
                      desc:     desc,
                      on:       _toggles[key]!,
                      required: isRequired,
                      onToggle: isRequired ? null : (v) => setState(() => _toggles[key] = v),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              _PrimaryButton(
                label:   _isRequesting
                    ? s.t('جاري الطلب...', 'Requesting…')
                    : s.t('السماح والمتابعة', 'Allow and continue'),
                loading: _isRequesting,
                onTap:   _isRequesting ? null : _requestAndContinue,
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  s.t(
                    'يمكنك تغيير هذه الأذونات لاحقاً في الإعدادات.',
                    'You can change any of these later in Settings.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _kInk, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Permission row ─────────────────────────────────────────────────────────────

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.label, required this.desc,
    required this.on, required this.required, required this.onToggle,
  });

  final String label; final String desc;
  final bool on; final bool required;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final requiredLabel = AppSettings().t('مطلوب', 'REQUIRED');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: _kLine))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: _kSoft, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Text(label[0],
                style: const TextStyle(color: _kNavy, fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(label, style: const TextStyle(color: _kNavy, fontSize: 16, fontWeight: FontWeight.w600)),
                  if (required) ...[
                    const SizedBox(width: 8),
                    Text(requiredLabel,
                        style: const TextStyle(color: _kSteel, fontSize: 11,
                            fontWeight: FontWeight.w600, letterSpacing: 0.6)),
                  ],
                ]),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: _kInk, fontSize: 14, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: onToggle == null ? null : () => onToggle!(!on),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44, height: 26,
                decoration: BoxDecoration(
                  color: on ? _kSteel : const Color(0xFFCFCABF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, color: Colors.white,
                        boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 3, offset: const Offset(0, 1),
                        )],
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
}

// ── Primary button ─────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.loading, required this.onTap});
  final String label; final bool loading; final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: onTap == null ? _kNavy.withValues(alpha: 0.5) : _kNavy,
          borderRadius: BorderRadius.circular(14),
        ),
        child: loading
            ? const Center(child: SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: _kCream, strokeWidth: 2.5)))
            : Text(label, textAlign: TextAlign.center,
                style: const TextStyle(color: _kCream, fontSize: 18, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
