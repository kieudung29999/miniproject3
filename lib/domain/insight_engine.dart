import 'package:receipt_tracker/core/formatters.dart';

enum Verdict { more, less, normal }

extension VerdictLabel on Verdict {
  String get label {
    switch (this) {
      case Verdict.more:
        return 'CHI NHIỀU';
      case Verdict.less:
        return 'CHI ÍT';
      case Verdict.normal:
        return 'BÌNH THƯỜNG';
    }
  }
}

class CategoryChange {
  const CategoryChange(this.categoryId, this.name, this.delta, this.pct);
  final int categoryId;
  final String name;
  final double delta;

  /// delta / tháng trước (1.0 = +100%).
  final double pct;
}

class MonthInsight {
  const MonthInsight({
    required this.verdict,
    required this.summary,
    this.pctVsPrev,
    this.pctVsAvg3,
    this.topIncrease,
    this.topDecrease,
  });
  final Verdict verdict;
  final String summary;
  final double? pctVsPrev;
  final double? pctVsAvg3;
  final CategoryChange? topIncrease;
  final CategoryChange? topDecrease;
}

/// Phân tích rule-based, chạy hoàn toàn offline.
class InsightEngine {
  static const double threshold = 0.15;

  static String _pct(double v) => '${v >= 0 ? '+' : ''}${(v * 100).toStringAsFixed(0)}%';

  static MonthInsight analyze({
    required double total,
    required double prev,
    required double avg3,
    required Map<int, double> cat,
    required Map<int, double> prevCat,
    required Map<int, String> names,
  }) {
    if (total <= 0) {
      return const MonthInsight(
        verdict: Verdict.normal,
        summary: 'Chưa có dữ liệu chi tiêu trong tháng này.',
      );
    }
    final pPrev = prev > 0 ? (total - prev) / prev : null;
    final pAvg = avg3 > 0 ? (total - avg3) / avg3 : null;
    final base = pAvg ?? pPrev;
    final verdict = base == null
        ? Verdict.normal
        : base > threshold
            ? Verdict.more
            : base < -threshold
                ? Verdict.less
                : Verdict.normal;

    CategoryChange? up, down;
    final ids = {...cat.keys, ...prevCat.keys};
    for (final id in ids) {
      final cur = cat[id] ?? 0;
      final old = prevCat[id] ?? 0;
      final d = cur - old;
      final pct = old > 0 ? d / old : (cur > 0 ? 1.0 : 0.0);
      final c = CategoryChange(id, names[id] ?? 'Khác', d, pct);
      if (d > 0 && (up == null || d > up.delta)) up = c;
      if (d < 0 && (down == null || d < down.delta)) down = c;
    }

    final b = StringBuffer('Tháng này bạn chi ${fmtMoney(total)}');
    if (pPrev != null) b.write(', ${_pct(pPrev)} so với tháng trước');
    if (pAvg != null) b.write(' và ${_pct(pAvg)} so với trung bình 3 tháng (${fmtMoney(avg3)})');
    b.write('. ');
    switch (verdict) {
      case Verdict.more:
        b.write('Mức chi đang CAO hơn bình thường (ngưỡng ±15%). ');
        break;
      case Verdict.less:
        b.write('Mức chi đang THẤP hơn bình thường (ngưỡng ±15%). ');
        break;
      case Verdict.normal:
        b.write('Mức chi trong khoảng BÌNH THƯỜNG (ngưỡng ±15%). ');
        break;
    }
    if (up != null) {
      b.write('Danh mục tăng mạnh nhất: ${up.name} (+${fmtMoney(up.delta)}). ');
    }
    if (down != null) {
      b.write('Danh mục giảm mạnh nhất: ${down.name} (${fmtMoney(down.delta)}).');
    }
    return MonthInsight(
      verdict: verdict,
      summary: b.toString().trim(),
      pctVsPrev: pPrev,
      pctVsAvg3: pAvg,
      topIncrease: up,
      topDecrease: down,
    );
  }
}
