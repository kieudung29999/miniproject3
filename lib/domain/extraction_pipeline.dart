import 'dart:math';

import 'package:receipt_tracker/core/constants.dart';
import 'package:receipt_tracker/data/models/transaction.dart';
import 'package:receipt_tracker/domain/gemini_service.dart';
import 'package:receipt_tracker/domain/regex_parser.dart';

class ExtractionResult {
  const ExtractionResult({
    required this.parsed,
    required this.source,
    required this.rawText,
    this.categoryName,
    this.items = const [],
    this.warning,
  });

  final ParsedTransaction parsed;

  /// regex | gemini
  final String source;
  final String rawText;
  final String? categoryName;
  final List<Map<String, dynamic>> items;
  final String? warning;

  ExtractionResult withWarning(String w) => ExtractionResult(
        parsed: parsed,
        source: source,
        rawText: rawText,
        categoryName: categoryName,
        items: items,
        warning: w,
      );
}

/// Pipeline hybrid: regex luôn chạy -> Gemini nâng cấp khi đủ điều kiện,
/// mọi lỗi đều fallback về regex (không throw).
class ExtractionPipeline {
  ExtractionPipeline({
    required this.parser,
    required this.isOnline,
    this.gemini,
    this.aiEnhanced = false,
    this.categoryNames = const [],
  });

  final RegexParser parser;
  final Future<bool> Function() isOnline;
  final GeminiClient? gemini;
  final bool aiEnhanced;
  final List<String> categoryNames;

  Future<ExtractionResult> processReceipt(String rawText) => _run(rawText, sms: false);
  Future<ExtractionResult> processMessage(String text) => _run(text, sms: true);

  Future<ExtractionResult> _run(String text, {required bool sms}) async {
    final base = sms ? parser.parseSms(text) : parser.parseReceipt(text);
    final result = ExtractionResult(parsed: base, source: 'regex', rawText: text);

    final g = gemini;
    final needAi = base.confidence < kLowConfidence || base.amount == null || aiEnhanced;
    if (g == null || !needAi) return result;

    bool online;
    try {
      online = await isOnline();
    } catch (_) {
      online = false;
    }
    if (!online) {
      return base.confidence < kLowConfidence
          ? result.withWarning('Đang offline: dùng kết quả regex, hãy kiểm tra lại.')
          : result;
    }

    try {
      final ext = await g.extract(text, categories: categoryNames, isMessage: sms);
      final merchant = (ext.merchant != null && ext.merchant!.isNotEmpty)
          ? ext.merchant
          : base.merchant;
      final amount = ext.amount ?? base.amount;
      final merged = ParsedTransaction(
        amount: amount,
        date: ext.date ?? base.date,
        merchant: merchant,
        type: ext.type ?? base.type,
        confidence: ext.amount != null ? max(base.confidence, 0.9) : base.confidence,
        amountFromKeyword: base.amountFromKeyword || ext.amount != null,
      );
      return ExtractionResult(
        parsed: merged,
        source: ext.amount != null ? 'gemini' : 'regex',
        rawText: text,
        categoryName: ext.category,
        items: ext.items,
      );
    } on GeminiException catch (e) {
      return result.withWarning('${e.userMessage} Đã dùng kết quả regex.');
    } catch (_) {
      return result.withWarning('Lỗi khi gọi AI. Đã dùng kết quả regex.');
    }
  }
}
