// lib/core/command_router.dart
//
// Maps a free-form spoken command (any language) to one of the four
// app features.  Add keywords here as the vocabulary grows.

enum AppCommand {
  describe,
  readText,
  detectColor,
  estimateDistance,
  detectObject,
}

class CommandRouter {
  const CommandRouter._();

  static AppCommand route(String text) {
    final t = text.toLowerCase();
    if (_colorWords.any((w) => t.contains(w))) return AppCommand.detectColor;
    if (_textWords.any((w) => t.contains(w))) return AppCommand.readText;
    if (_distanceWords.any((w) => t.contains(w))) return AppCommand.estimateDistance;
    if (_objectWords.any((w) => t.contains(w))) return AppCommand.detectObject;
    return AppCommand.describe;
  }

  // ── Color ─────────────────────────────────────────────────────────────────
  static const _colorWords = [
    // Arabic
    'لون', 'اللون', 'لونه', 'لوني', 'ألوان', 'ما لون', 'ما اللون',
  ];

  // ── Text extraction ───────────────────────────────────────────────────────
  static const _textWords = [
    // Arabic
    'اقرأ', 'اقراء', 'نص', 'قراءة', 'مكتوب', 'كلمة', 'كلمات',
  ];

  // ── Distance estimation ───────────────────────────────────────────────────
  static const _distanceWords = [
    // Arabic
    'مسافة', 'بعد', 'بعيد', 'قريب', 'كم يبعد', 'كم المسافة',
  ];

  // ── Object detection ──────────────────────────────────────────────────────
  static const _objectWords = ['ما هذا', 'ماذا أمامي', 'اكتشف', 'تعرف', 'كشف'];
}
