import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receipt_tracker/core/constants.dart';
import 'package:receipt_tracker/core/formatters.dart';
import 'package:receipt_tracker/data/models/ai_insight.dart';
import 'package:receipt_tracker/data/models/category.dart';
import 'package:receipt_tracker/domain/gemini_service.dart';
import 'package:receipt_tracker/domain/insight_engine.dart';
import 'package:receipt_tracker/presentation/providers/providers.dart';
import 'package:receipt_tracker/presentation/widgets/charts.dart';
import 'package:receipt_tracker/presentation/widgets/common.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});
  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  int? _selected;
  bool _donut = true;
  bool _aiLoading = false;

  Future<void> _runAi(MonthStats s, Map<int, String> names) async {
    final settings = ref.read(settingsProvider);
    final online = ref.read(onlineProvider).valueOrNull ?? false;
    if (!settings.hasKey) {
      showSnack(context, 'Hãy nhập Gemini API key trong Cài đặt.');
      return;
    }
    if (!online) {
      showSnack(context, 'Cần kết nối mạng để phân tích bằng AI. Bạn vẫn xem được phân tích offline.');
      return;
    }
    setState(() => _aiLoading = true);
    try {
      // Chỉ gửi dữ liệu TỔNG HỢP: không ảnh, không tên cửa hàng, không ghi chú.
      final summary = jsonEncode({
        'month': monthKey(s.month),
        'total_expense': s.expense.round(),
        'prev_month_expense': s.prevExpense.round(),
        'avg_3_months_expense': s.avg3.round(),
        'total_income': s.income.round(),
        'categories': [
          for (final e in s.catTotals.entries)
            {
              'name': names[e.key] ?? 'Khác',
              'total': e.value.round(),
              'prev_total': (s.prevCatTotals[e.key] ?? 0).round(),
            }
        ],
        'weekly_expense': s.weekly.map((e) => e.round()).toList(),
      });
      final text = await GeminiService(apiKey: settings.apiKey!, model: settings.model)
          .analyze(summary);
      await ref.read(insightRepoProvider).save(AiInsight(
            month: monthKey(s.month),
            content: text,
            model: settings.model,
            createdAt: DateTime.now(),
          ));
      bumpData(ref);
    } on GeminiException catch (e) {
      if (mounted) showSnack(context, e.userMessage);
    } catch (_) {
      if (mounted) showSnack(context, 'Không thể phân tích bằng AI lúc này.');
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final month = ref.watch(selectedMonthProvider);
    final statsAsync = ref.watch(monthStatsProvider(month));
    final cats = ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    final insightAsync = ref.watch(cachedInsightProvider(month));
    final settings = ref.watch(settingsProvider);
    final online = ref.watch(onlineProvider).valueOrNull ?? false;
    final catMap = {for (final c in cats) c.id!: c};
    final names = {for (final c in cats) c.id!: c.name};

    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê')),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (s) {
          final entries = s.catTotals.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final values = entries.map((e) => e.value).toList();
          final colors =
              entries.map((e) => catMap[e.key]?.colorValue ?? Colors.grey).toList();
          final sel = (_selected != null && _selected! < entries.length) ? _selected : null;
          final selEntry = sel == null ? null : entries[sel];
          final insight = InsightEngine.analyze(
            total: s.expense,
            prev: s.prevExpense,
            avg3: s.avg3,
            cat: s.catTotals,
            prevCat: s.prevCatTotals,
            names: names,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, kNavSpace),
            children: [
              const MonthSelector(),
              AppCard(
                radius: 24,
                child: Column(children: [
                  Row(children: [
                    Expanded(
                      child: Text('Chi tiêu theo danh mục',
                          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(visualDensity: VisualDensity.compact),
                      segments: const [
                        ButtonSegment(value: true, label: Text('Donut')),
                        ButtonSegment(value: false, label: Text('Pie')),
                      ],
                      selected: {_donut},
                      onSelectionChanged: (v) => setState(() => _donut = v.first),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  if (entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Chưa có chi tiêu trong tháng này.'),
                    )
                  else ...[
                    DonutChart(
                      values: values,
                      colors: colors,
                      donut: _donut,
                      selected: sel,
                      onSelected: (i) => setState(() => _selected = i),
                      centerLabel: selEntry == null
                          ? 'Tổng chi'
                          : (names[selEntry.key] ?? 'Khác'),
                      centerValue: fmtMoney(selEntry?.value ?? s.expense),
                    ),
                    const SizedBox(height: 12),
                    if (selEntry != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors[sel!].withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${names[selEntry.key] ?? 'Khác'}: ${fmtMoney(selEntry.value)} '
                          '(${(selEntry.value / s.expense * 100).toStringAsFixed(1)}% tổng chi)'
                          '${(s.prevCatTotals[selEntry.key] ?? 0) > 0 ? ' • tháng trước ${fmtMoney(s.prevCatTotals[selEntry.key]!)}' : ''}',
                        ),
                      ),
                    for (var i = 0; i < entries.length; i++)
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _selected = _selected == i ? null : i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                          child: Row(children: [
                            CircleAvatar(radius: 6, backgroundColor: colors[i]),
                            const SizedBox(width: 10),
                            Expanded(child: Text(names[entries[i].key] ?? 'Khác')),
                            Text(fmtMoney(entries[i].value),
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 44,
                              child: Text(
                                '${(entries[i].value / s.expense * 100).toStringAsFixed(0)}%',
                                textAlign: TextAlign.right,
                                style: t.textTheme.bodySmall
                                    ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                              ),
                            ),
                          ]),
                        ),
                      ),
                  ],
                ]),
              ),
              const SizedBox(height: 16),
              AppCard(
                radius: 24,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Biến động chi tiêu theo tuần',
                      style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  WeeklyBarChart(values: s.weekly),
                ]),
              ),
              const SizedBox(height: 16),
              AppCard(
                radius: 24,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text('Phân tích tháng (offline)',
                          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (insight.verdict == Verdict.more
                                ? AppColors.bad
                                : insight.verdict == Verdict.less
                                    ? AppColors.good
                                    : Colors.blueGrey)
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(insight.verdict.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: insight.verdict == Verdict.more
                                ? AppColors.bad
                                : insight.verdict == Verdict.less
                                    ? AppColors.good
                                    : Colors.blueGrey,
                          )),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text(insight.summary),
                ]),
              ),
              const SizedBox(height: 16),
              AppCard(
                radius: 24,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.auto_awesome, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Phân tích bằng AI',
                          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  insightAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (ins) => ins == null
                        ? Text(
                            'Chưa có phân tích AI cho tháng này. Kết quả sẽ được lưu để xem lại khi offline.',
                            style: t.textTheme.bodySmall
                                ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                          )
                        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            SelectableText(ins.content),
                            const SizedBox(height: 6),
                            Text('${ins.model} • ${fmtDateTime(ins.createdAt)}',
                                style: t.textTheme.bodySmall
                                    ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                          ]),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: (_aiLoading || s.expense <= 0) ? null : () => _runAi(s, names),
                    icon: _aiLoading
                        ? const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome),
                    label: Text(_aiLoading ? 'Đang phân tích…' : 'Phân tích bằng AI'),
                  ),
                  if (!settings.hasKey || !online)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        !settings.hasKey
                            ? 'Cần nhập API key trong Cài đặt.'
                            : 'Đang offline — nút sẽ hoạt động khi có mạng.',
                        style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
                      ),
                    ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}
