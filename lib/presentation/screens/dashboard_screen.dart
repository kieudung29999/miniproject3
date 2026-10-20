import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receipt_tracker/core/constants.dart';
import 'package:receipt_tracker/core/formatters.dart';
import 'package:receipt_tracker/data/models/category.dart';
import 'package:receipt_tracker/domain/seed_data.dart';
import 'package:receipt_tracker/presentation/providers/providers.dart';
import 'package:receipt_tracker/presentation/screens/review_screen.dart';
import 'package:receipt_tracker/presentation/widgets/common.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    final stats = ref.watch(monthStatsProvider(month));
    final cats = ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    final catMap = {for (final c in cats) c.id!: c};

    return stats.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi tải dữ liệu: $e')),
      data: (s) {
        final hasData = s.recent.isNotEmpty;
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(total: s.expense, pct: s.pctVsPrev, month: month),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(children: [
                Expanded(
                  child: KpiCard(
                    icon: Icons.north_east_rounded,
                    label: 'Chi tháng này',
                    value: fmtMoney(s.expense),
                    badge: PctBadge(pct: s.pctVsPrev),
                    iconColor: AppColors.bad,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: KpiCard(
                    icon: Icons.south_west_rounded,
                    label: 'Thu tháng này',
                    value: fmtMoney(s.income),
                    iconColor: AppColors.good,
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, kNavSpace),
              child: AppCard(
                radius: 24,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Giao dịch gần đây',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (!hasData) ...[
                    const SizedBox(height: 12),
                    const Text('Chưa có giao dịch nào. Quét hóa đơn hoặc nạp dữ liệu demo để thử.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () async {
                        final c = await ref.read(categoriesProvider.future);
                        await ref
                            .read(txRepoProvider)
                            .insertAll(generateDemoTransactions(c));
                        bumpData(ref);
                      },
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Nạp dữ liệu demo'),
                    ),
                  ],
                  for (final t in s.recent)
                    TxTile(
                      tx: t,
                      category: catMap[t.categoryId],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ReviewScreen(initial: t)),
                      ),
                    ),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.total, required this.pct, required this.month});
  final double total;
  final double? pct;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
            child: Text('Receipt & Expense',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          const OnlineBadge(),
        ]),
        const SizedBox(height: 22),
        Text('Tổng chi tháng ${fmtMonth(month)}',
            style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 13)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(fmtMoney(total),
              style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 10),
        if (pct != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: AppColors.lime, borderRadius: BorderRadius.circular(30)),
            child: Text(
              '${pct! >= 0 ? '▲' : '▼'} ${pct!.abs().toStringAsFixed(0)}% so với tháng trước',
              style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
      ]),
    );
  }
}
