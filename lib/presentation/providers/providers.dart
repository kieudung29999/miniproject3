import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receipt_tracker/core/formatters.dart';
import 'package:receipt_tracker/data/db/app_database.dart';
import 'package:receipt_tracker/data/models/ai_insight.dart';
import 'package:receipt_tracker/data/models/category.dart';
import 'package:receipt_tracker/data/models/transaction.dart';
import 'package:receipt_tracker/data/repositories/category_repository.dart';
import 'package:receipt_tracker/data/repositories/insight_repository.dart';
import 'package:receipt_tracker/data/repositories/transaction_repository.dart';
import 'package:receipt_tracker/domain/extraction_pipeline.dart';
import 'package:receipt_tracker/domain/gemini_service.dart';
import 'package:receipt_tracker/domain/ocr_service.dart';
import 'package:receipt_tracker/domain/regex_parser.dart';
import 'package:receipt_tracker/domain/settings_service.dart';

// ---------------------------------------------------------------- repos
final categoryRepoProvider = Provider((ref) => CategoryRepository(AppDatabase.instance));
final txRepoProvider = Provider((ref) => TransactionRepository(AppDatabase.instance));
final insightRepoProvider = Provider((ref) => InsightRepository(AppDatabase.instance));

/// Tăng mỗi khi dữ liệu đổi -> các provider phụ thuộc tự tính lại.
final dataVersionProvider = StateProvider<int>((_) => 0);
void bumpData(WidgetRef ref) => ref.read(dataVersionProvider.notifier).state++;

// ------------------------------------------------------------- settings
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) => SettingsNotifier());

// --------------------------------------------------------- connectivity
bool _isOn(List<ConnectivityResult> r) => r.any((e) => e != ConnectivityResult.none);

final onlineProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  try {
    yield _isOn(await c.checkConnectivity());
  } catch (_) {
    yield false;
  }
  yield* c.onConnectivityChanged.map(_isOn);
});

// --------------------------------------------------------------- domain
final ocrServiceProvider = Provider<OcrService>((ref) {
  final s = OcrService();
  ref.onDispose(s.dispose);
  return s;
});

final pipelineProvider = Provider<ExtractionPipeline>((ref) {
  final s = ref.watch(settingsProvider);
  final cats = ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
  final GeminiClient? g =
      s.hasKey ? GeminiService(apiKey: s.apiKey!, model: s.model) : null;
  return ExtractionPipeline(
    parser: const RegexParser(),
    isOnline: () async => _isOn(await Connectivity().checkConnectivity()),
    gemini: g,
    aiEnhanced: s.aiEnhanced,
    categoryNames: cats.map((c) => c.name).toList(),
  );
});

// ----------------------------------------------------------------- data
final categoriesProvider =
    FutureProvider<List<Category>>((ref) => ref.watch(categoryRepoProvider).all());

final selectedMonthProvider = StateProvider<DateTime>((_) {
  final n = DateTime.now();
  return DateTime(n.year, n.month);
});
final searchProvider = StateProvider<String>((_) => '');
final categoryFilterProvider = StateProvider<int?>((_) => null);

final transactionsProvider = FutureProvider.autoDispose<List<AppTransaction>>((ref) {
  ref.watch(dataVersionProvider);
  return ref.watch(txRepoProvider).query(
        month: ref.watch(selectedMonthProvider),
        categoryId: ref.watch(categoryFilterProvider),
        search: ref.watch(searchProvider),
      );
});

class MonthStats {
  const MonthStats({
    required this.month,
    required this.expense,
    required this.prevExpense,
    required this.income,
    required this.avg3,
    required this.catTotals,
    required this.prevCatTotals,
    required this.weekly,
    required this.recent,
  });
  final DateTime month;
  final double expense;
  final double prevExpense;
  final double income;
  final double avg3;
  final Map<int, double> catTotals;
  final Map<int, double> prevCatTotals;
  final List<double> weekly;
  final List<AppTransaction> recent;

  double? get pctVsPrev => prevExpense > 0 ? (expense - prevExpense) / prevExpense * 100 : null;
}

final monthStatsProvider =
    FutureProvider.autoDispose.family<MonthStats, DateTime>((ref, month) async {
  ref.watch(dataVersionProvider);
  final repo = ref.watch(txRepoProvider);
  final prevMonth = DateTime(month.year, month.month - 1);

  final expense = await repo.monthTotal(month, TxType.expense);
  final prev = await repo.monthTotal(prevMonth, TxType.expense);
  final income = await repo.monthTotal(month, TxType.income);

  final olds = <double>[];
  for (var i = 1; i <= 3; i++) {
    final t = await repo.monthTotal(DateTime(month.year, month.month - i), TxType.expense);
    if (t > 0) olds.add(t);
  }
  final avg3 = olds.isEmpty ? 0.0 : olds.reduce((a, b) => a + b) / olds.length;

  final cat = await repo.categoryTotals(month, TxType.expense);
  final prevCat = await repo.categoryTotals(prevMonth, TxType.expense);

  final inMonth = await repo.query(month: month);
  final weekly = List<double>.filled(5, 0);
  for (final t in inMonth) {
    if (t.type == TxType.expense) weekly[min((t.date.day - 1) ~/ 7, 4)] += t.amount;
  }
  final recent = await repo.query(limit: 6);

  return MonthStats(
    month: month,
    expense: expense,
    prevExpense: prev,
    income: income,
    avg3: avg3,
    catTotals: cat,
    prevCatTotals: prevCat,
    weekly: weekly,
    recent: recent,
  );
});

final cachedInsightProvider =
    FutureProvider.autoDispose.family<AiInsight?, DateTime>((ref, month) {
  ref.watch(dataVersionProvider);
  return ref.watch(insightRepoProvider).latest(monthKey(month));
});
