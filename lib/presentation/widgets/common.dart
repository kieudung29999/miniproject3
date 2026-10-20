import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receipt_tracker/core/constants.dart';
import 'package:receipt_tracker/core/formatters.dart';
import 'package:receipt_tracker/data/models/category.dart';
import 'package:receipt_tracker/data/models/transaction.dart';
import 'package:receipt_tracker/presentation/providers/providers.dart';

/// Chừa chỗ cho thanh điều hướng nổi.
const double kNavSpace = 110;

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.onTap,
    this.color,
  });
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final dark = t.brightness == Brightness.dark;
    return Material(
      color: color ?? t.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: dark ? 0 : 1.5,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class OnlineBadge extends ConsumerWidget {
  const OnlineBadge({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(onlineProvider).valueOrNull ?? true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x2EFFFFFF),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 9, color: on ? AppColors.lime : Colors.orangeAccent),
          const SizedBox(width: 6),
          Text(on ? 'Online' : 'Offline',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Badge % thay đổi. Với chi tiêu: giảm = xanh (tốt), tăng = đỏ (xấu).
class PctBadge extends StatelessWidget {
  const PctBadge({super.key, required this.pct, this.upIsBad = true});
  final double? pct;
  final bool upIsBad;

  @override
  Widget build(BuildContext context) {
    if (pct == null) return const SizedBox.shrink();
    final up = pct! > 0;
    final good = upIsBad ? !up : up;
    final c = good ? AppColors.good : AppColors.bad;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(up ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: c),
        const SizedBox(width: 2),
        Text('${pct!.abs().toStringAsFixed(0)}%',
            style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.badge,
    this.iconColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Widget? badge;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return AppCard(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: (iconColor ?? t.colorScheme.primary).withOpacity(0.14),
              child: Icon(icon, size: 18, color: iconColor ?? t.colorScheme.primary),
            ),
            const Spacer(),
            if (badge != null) badge!,
          ]),
          const SizedBox(height: 14),
          Text(label, style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class MonthSelector extends ConsumerWidget {
  const MonthSelector({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(selectedMonthProvider);
    final now = DateTime.now();
    final isCurrent = m.year == now.year && m.month == now.month;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () => ref.read(selectedMonthProvider.notifier).state =
              DateTime(m.year, m.month - 1),
          icon: const Icon(Icons.chevron_left),
        ),
        Text('Tháng ${fmtMonth(m)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        IconButton(
          onPressed: isCurrent
              ? null
              : () => ref.read(selectedMonthProvider.notifier).state =
                  DateTime(m.year, m.month + 1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class SourceChip extends StatelessWidget {
  const SourceChip(this.source, {super.key});
  final String source;
  @override
  Widget build(BuildContext context) {
    final label = source == 'gemini' ? 'AI' : (source == 'regex' ? 'OCR' : 'Tay');
    final c = source == 'gemini'
        ? Colors.purple
        : (source == 'regex' ? Colors.blue : Colors.grey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: c.withOpacity(0.14), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w800)),
    );
  }
}

class TxTile extends StatelessWidget {
  const TxTile({super.key, required this.tx, required this.category, this.onTap});
  final AppTransaction tx;
  final Category? category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final income = tx.type == TxType.income;
    final c = category?.colorValue ?? Colors.grey;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: c.withOpacity(0.16),
            child: Icon(category?.iconData ?? Icons.category, color: c, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                (tx.merchant?.isNotEmpty ?? false) ? tx.merchant! : (category?.name ?? 'Giao dịch'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Row(children: [
                Flexible(
                  child: Text('${category?.name ?? '—'} • ${fmtDate(tx.date)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                ),
                const SizedBox(width: 6),
                SourceChip(tx.source),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          Text('${income ? '+' : '-'}${fmtMoney(tx.amount)}',
              style: t.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: income ? AppColors.good : t.colorScheme.onSurface,
              )),
        ]),
      ),
    );
  }
}

void showSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
    ));
}

void showFullImage(BuildContext context, String path) {
  showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: InteractiveViewer(child: Image.file(File(path))),
    ),
  );
}
