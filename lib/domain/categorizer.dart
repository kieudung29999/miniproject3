import 'package:receipt_tracker/core/constants.dart';
import 'package:receipt_tracker/core/text_utils.dart';
import 'package:receipt_tracker/data/models/category.dart';
import 'package:receipt_tracker/data/models/transaction.dart';

/// Phân loại danh mục bằng bảng từ khóa offline; nhận gợi ý từ Gemini nếu có.
class Categorizer {
  Categorizer(this.categories);
  final List<Category> categories;

  Category? byName(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    final n = removeDiacritics(name.trim());
    for (final c in categories) {
      if (removeDiacritics(c.name) == n) return c;
    }
    return null;
  }

  Category categorize(String text, {TxType type = TxType.expense, String? aiName}) {
    final fallback = byName(kOtherCategory) ?? categories.first;
    if (type == TxType.income) return byName(kIncomeCategory) ?? fallback;

    final ai = byName(aiName);
    if (ai != null && ai.name != kIncomeCategory) return ai;

    final norm = removeDiacritics(text);
    Category? best;
    var bestScore = 0;
    for (final c in categories) {
      if (c.name == kOtherCategory || c.name == kIncomeCategory) continue;
      var score = 0;
      for (final k in c.keywordList) {
        if (RegExp('(?<![a-z0-9])${RegExp.escape(k)}(?![a-z0-9])').hasMatch(norm)) {
          score += k.length;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    return best ?? fallback;
  }
}
