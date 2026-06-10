import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'command_router.dart';

// ─── Groq config ─────────────────────────────────────────────────────────────

const _kGroqApiUrl = 'https://api.groq.com/openai/v1/chat/completions';
const _kGroqModel  = 'llama-3.3-70b-versatile';

/// Maximum time to wait for a Groq response before falling back locally.
const _kTimeout = Duration(seconds: 5);

// ─── Prompts ─────────────────────────────────────────────────────────────────

const _kIntentSystemPrompt = '''
أنت نظام تصنيف أوامر لتطبيق بصير — تطبيق مساعد للمكفوفين يستخدم كاميرا الهاتف لتحليل المحيط.

مهمتك الوحيدة: تحديد نية المستخدم من صوته وإرجاعها كـ JSON.

─── الأوامر المتاحة ──────────────────────────────────────────────────────────

detect_object
  المستخدم يريد معرفة ما يوجد أمامه في المشهد.
  يشمل: طلب وصف المشهد، سؤال عن وجود شيء معين، التعرف على الأشياء،
         فهم البيئة المحيطة، الملاحة، سؤال عن مكان شيء ما.
  أمثلة: "فيه إيه قدامي"، "في كوباية؟"، "أنا فين؟"، "في حد قريب مني؟"،
          "وصف اللي قدامي"، "إيه الحاجات الموجودة"، "ما هذا"، "عارفني تقولي إيه ده"

detect_color
  المستخدم يريد معرفة لون شيء ما.
  يشمل: أي سؤال عن اللون، الألوان، المقارنة بين ألوان.
  أمثلة: "اللون إيه"، "ده لونه إيه"، "القميص ده لونه إيه"، "الألوان قدامي إيه"

read_text
  المستخدم يريد قراءة نص مكتوب.
  يشمل: قراءة لافتات، كتب، رسائل، أكواد، أي نص مكتوب في المشهد.
  أمثلة: "اقرا اللي مكتوب"، "في نص قدامي"، "الورقة دي بتقول إيه"،
          "اقرا اللافتة"، "كلمة مكتوبة على الباب"

talk
  المستخدم يريد التحدث مع بصير بشكل عام — ليس طلب تحليل كاميرا.
  يشمل حصراً: التحية، الوداع، الشكر، الأسئلة الشخصية عن بصير،
               الأسئلة العامة التي لا تحتاج الكاميرا.
  أمثلة: "أهلاً يا بصير"، "إزيك"، "شكراً"، "بتعرف تعمل إيه"، "مع السلامة"

─── قاعدة حاسمة ────────────────────────────────────────────────────────────

⚠️  الغالبية العظمى من الأوامر هي طلبات مساعدة بالكاميرا (detect_object / detect_color / read_text).
    أرجع "talk" فقط لو أنت متأكد 100٪ أن المستخدم يتحدث مع بصير ولا يطلب أي تحليل.
    أي شك → لا ترجع "talk".

─── تنسيق الخرج ─────────────────────────────────────────────────────────────

أرجع JSON فقط، بدون أي كلام إضافي أو markdown:
{"intent": "<detect_object|detect_color|read_text|talk>"}
''';

const _kResponseSystemPrompt = '''
أنت بصير — مساعد صوتي ذكي وحساس للمكفوفين.

المستخدم لا يرى، ويعتمد عليك كلياً لفهم محيطه. ردودك تُقرأ بصوت عالٍ فور انتهائها، لذلك:

─── مبادئ الرد ──────────────────────────────────────────────────────────────

١. الأهم أولاً — ابدأ بأهم المعلومات مباشرة بدون مقدمات.
   ✗ "بناءً على تحليل الصورة، يمكنني إخبارك أن..."
   ✓ "قدامك كوباية شاي على بعد ٤٠ سم."

٢. الإيجاز — جملة أو جملتين تكفي. الصمت وقت الانتظار مقلق للمستخدم.

٣. الدقة — أجب على السؤال المحدد اللي سأله المستخدم، مش معلومات زيادة.
   لو سأل "في حد قدامي؟" قول "أيوه، في شخص قدامك." — مش كل تفاصيل المشهد.

٤. الحساسية — استخدم "أنا شايف" أو "قدامك" بدل "الصورة تظهر".
   تكلم كأنك أنت اللي بتشوف نيابة عنه.

٥. الترجمة — ترجم الكلمات الإنجليزية تلقائياً:
   bottle→زجاجة، cup→كوباية، chair→كرسي، table→ترابيزة،
   person→شخص، car→عربية، phone→تليفون، book→كتاب، laptop→لابتوب،
   door→باب، window→شباك، bag→شنطة، keyboard→كيبورد

٦. لو النتيجة فاضية أو مفيش حاجة — قول "مش شايف حاجة واضحة قدامك."

─── اللغة ───────────────────────────────────────────────────────────────────

عامية مصرية طبيعية، دافئة وواثقة.

─── الخرج ───────────────────────────────────────────────────────────────────

النص فقط، بدون JSON أو تنسيق أو نقاط أو أرقام.
''';

// ─── LlmRouter ───────────────────────────────────────────────────────────────

class LlmRouter {
  LlmRouter._();

  static final LlmRouter instance = LlmRouter._();

  String? get _apiKey => dotenv.env['GROQ_API_KEY']?.trim();

  // ── Public API ────────────────────────────────────────────────────────────

  /// Classifies [command] into an [AppCommand].
  ///
  /// Falls back to [CommandRouter.route] if the LLM is unavailable or returns
  /// an unrecognised intent.
  Future<AppCommand> classifyIntent(String command) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      debugPrint('[LlmRouter] No GROQ_API_KEY — using local fallback');
      return CommandRouter.route(command);
    }

    try {
      final raw = await _callGroq(
        systemPrompt: _kIntentSystemPrompt,
        userMessage: command,
        maxTokens: 32,
      );
      return _parseIntent(raw) ?? CommandRouter.route(command);
    } catch (e) {
      debugPrint('[LlmRouter] classifyIntent failed: $e — falling back');
      return CommandRouter.route(command);
    }
  }

  /// Wraps [functionOutput] in a natural Arabic sentence that directly answers
  /// [originalCommand].
  ///
  /// Falls back to returning [functionOutput] unchanged if the LLM call fails.
  Future<String> generateResponse({
    required String originalCommand,
    required String functionOutput,
  }) async {
    if (functionOutput.isEmpty) return 'مش شايف حاجة واضحة قدامك.';

    if (_apiKey == null || _apiKey!.isEmpty) {
      debugPrint('[LlmRouter] No GROQ_API_KEY — skipping response generation');
      return functionOutput;
    }

    try {
      final userMessage =
          'سؤال المستخدم: $originalCommand\nنتيجة التحليل: $functionOutput';

      final response = await _callGroq(
        systemPrompt: _kResponseSystemPrompt,
        userMessage: userMessage,
        maxTokens: 150,
      );

      final trimmed = response.trim();
      return trimmed.isNotEmpty ? trimmed : functionOutput;
    } catch (e) {
      debugPrint('[LlmRouter] generateResponse failed: $e — using raw output');
      return functionOutput;
    }
  }

  // ── Groq HTTP call ────────────────────────────────────────────────────────

  Future<String> _callGroq({
    required String systemPrompt,
    required String userMessage,
    required int maxTokens,
  }) async {
    final body = jsonEncode({
      'model': _kGroqModel,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user',   'content': userMessage},
      ],
      'temperature': 0.1,
      'max_tokens': maxTokens,
    });

    final response = await http
        .post(
          Uri.parse(_kGroqApiUrl),
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          body: body,
        )
        .timeout(_kTimeout);

    if (response.statusCode != 200) {
      throw Exception('Groq API ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['choices'][0]['message']['content'] as String;
  }

  // ── Response parsing ──────────────────────────────────────────────────────

  /// Extracts an [AppCommand] from the raw JSON string returned by the LLM.
  /// Returns null if parsing fails — the caller will fall back to [CommandRouter].
  AppCommand? _parseIntent(String raw) {
    try {
      final cleaned = raw
          .replaceAll(RegExp(r'```[a-z]*', caseSensitive: false), '')
          .replaceAll('```', '')
          .trim();

      final start = cleaned.indexOf('{');
      final end   = cleaned.lastIndexOf('}');
      if (start == -1 || end == -1) return null;

      final map    = jsonDecode(cleaned.substring(start, end + 1)) as Map<String, dynamic>;
      final intent = map['intent'] as String?;

      return switch (intent) {
        'detect_object' => AppCommand.detectObject,
        'detect_color'  => AppCommand.detectColor,
        'read_text'     => AppCommand.readText,
        'talk'          => AppCommand.talk,
        _               => null,
      };
    } catch (e) {
      debugPrint('[LlmRouter] _parseIntent error: $e — raw: $raw');
      return null;
    }
  }
}