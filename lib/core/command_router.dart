// lib/core/command_router.dart
//
// Maps a free-form spoken command (any language) to one of the four
// app features.  Add keywords here as the vocabulary grows.

enum AppCommand { describe, readText, detectColor, estimateDistance }

class CommandRouter {
  const CommandRouter._();

  static AppCommand route(String text) {
    final t = text.toLowerCase();
    if (_colorWords.any((w) => t.contains(w)))     return AppCommand.detectColor;
    if (_textWords.any((w) => t.contains(w)))      return AppCommand.readText;
    if (_distanceWords.any((w) => t.contains(w)))  return AppCommand.estimateDistance;
    return AppCommand.describe;
  }

  // ── Color ─────────────────────────────────────────────────────────────────
  static const _colorWords = [
    // English
    'color', 'colour',
    // Arabic
    'لون', 'اللون', 'لونه', 'لوني', 'ألوان', 'ما لون', 'ما اللون',
    // French
    'couleur',
    // German/other common langs
    'farbe',
  ];

  // ── Text extraction ───────────────────────────────────────────────────────
  static const _textWords = [
    // English
    'read', 'text', 'ocr', 'written', 'writing',
    // Arabic
    'اقرأ', 'اقراء', 'نص', 'قراءة', 'مكتوب', 'كلمة', 'كلمات',
    // French
    'lire', 'texte',
  ];

  // ── Distance estimation ───────────────────────────────────────────────────
  static const _distanceWords = [
    // English
    'distance', 'far', 'close', 'near', 'how far',
    // Arabic
    'مسافة', 'بعد', 'بعيد', 'قريب', 'كم يبعد', 'كم المسافة',
    // French
    'distance', 'loin', 'proche',
  ];
}
