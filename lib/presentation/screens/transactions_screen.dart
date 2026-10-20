import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receipt_tracker/data/models/category.dart';
import 'package:receipt_tracker/data/models/transaction.dart';
import 'package:receipt_tracker/presentation/providers/providers.dart';
import 'package:receipt_tracker/presentation/screens/review_screen.dart';
import 'package:receipt_tracker/presentation/screens/sms_import_screen.dart';
import 'package:receipt_tracker/presentation/widgets/common.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(transactionsProvider);
    final cats = ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    final catMap = {for (final c in cats) c.id!: c};
    final selCat = ref.watch(categoryFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giao dịch'),
        actions: [
          IconButton(
            tooltip: 'Nhập từ tin nhắn',
            icon: const Icon(Icons.sms_outlined),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SmsImportScreen())),
          ),
          IconButton(
            tooltip: 'Thêm thủ công',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              final now = DateTime.now();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ReviewScreen(
                  initial: AppTransaction(
                    amount: 0,
                    type: TxType.expense,
                    date: now,
                    source: 'manual',
                    createdAt: now,
                  ),
                ),
              ));
            },
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: TextField(
            onChanged: (v) => ref.read(searchProvider.notifier).state = v,
            decoration: const InputDecoration(
              hintText: 'Tìm theo cửa hàng, ghi chú…',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        const MonthSelector(),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: const Text('Tất cả'),
                  selected: selCat == null,
                  onSelected: (_) => ref.read(categoryFilterProvider.notifier).state = null,
                ),
              ),
              for (final c in cats)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(c.name),
                    selected: selCat == c.id,
                    onSelected: (_) => ref.read(categoryFilterProvider.notifier).state =
                        selCat == c.id ? null : c.id,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: txs.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Lỗi: $e')),
            data: (list) {
              if (list.isEmpty) {
                return const Center(child: Text('Không có giao dịch phù hợp.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, kNavSpace),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final t = list[i];
                  return Dismissible(
                    key: ValueKey('tx_${t.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Colors.red.shade400,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) async {
                      await ref.read(txRepoProvider).delete(t.id!);
                      bumpData(ref);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(
                          content: const Text('Đã xóa giao dịch'),
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          action: SnackBarAction(
                            label: 'Hoàn tác',
                            onPressed: () async {
                              await ref.read(txRepoProvider).insert(t);
                              bumpData(ref);
                            },
                          ),
                        ));
                    },
                    child: TxTile(
                      tx: t,
                      category: catMap[t.categoryId],
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => ReviewScreen(initial: t))),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
