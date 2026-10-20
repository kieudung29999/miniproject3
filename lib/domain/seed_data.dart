import 'dart:math';

import 'package:receipt_tracker/core/constants.dart';
import 'package:receipt_tracker/data/models/category.dart';
import 'package:receipt_tracker/data/models/transaction.dart';

class _Tpl {
  const _Tpl(this.cat, this.merchants, this.min, this.max);
  final String cat;
  final List<String> merchants;
  final int min;
  final int max;
}

/// ~51 giao dịch demo trải trên 3 tháng gần nhất (deterministic).
List<AppTransaction> generateDemoTransactions(List<Category> cats) {
  final rnd = Random(42);
  final now = DateTime.now();
  final byName = {for (final c in cats) c.name: c};

  const tpls = <_Tpl>[
    _Tpl('Ăn uống', ['Highlands Coffee', 'Phúc Long', 'KFC', 'Quán Cơm Tấm', 'GrabFood', 'Phở Hòa'], 30000, 220000),
    _Tpl('Ăn uống', ['Starbucks', 'Pizza 4P\'s', 'Lẩu Thái'], 120000, 450000),
    _Tpl('Di chuyển', ['Grab', 'Xanh SM', 'Petrolimex'], 25000, 180000),
    _Tpl('Mua sắm', ['WinMart', 'Circle K', 'Shopee', 'Bách Hóa Xanh'], 50000, 600000),
    _Tpl('Hóa đơn & tiện ích', ['EVN', 'Viettel', 'FPT Internet'], 150000, 700000),
    _Tpl('Giải trí', ['CGV', 'Netflix', 'Spotify'], 60000, 300000),
    _Tpl('Sức khỏe', ['Long Châu', 'Pharmacity'], 40000, 350000),
    _Tpl('Giáo dục', ['Fahasa', 'Udemy'], 80000, 500000),
  ];
  // Trọng số: lặp lại template phổ biến.
  final pool = <_Tpl>[
    tpls[0], tpls[0], tpls[0], tpls[1], tpls[2], tpls[2], tpls[3], tpls[3],
    tpls[4], tpls[5], tpls[6], tpls[7],
  ];

  final out = <AppTransaction>[];
  for (var m = 0; m < 3; m++) {
    final base = DateTime(now.year, now.month - m);
    final maxDay = m == 0 ? now.day : 28;
    for (var k = 0; k < 16; k++) {
      final t = pool[rnd.nextInt(pool.length)];
      final merchant = t.merchants[rnd.nextInt(t.merchants.length)];
      final raw = t.min + rnd.nextInt(t.max - t.min);
      final amount = (raw ~/ 1000 * 1000).toDouble();
      final day = rnd.nextInt(maxDay) + 1;
      final d = DateTime(base.year, base.month, day, 8 + rnd.nextInt(12), rnd.nextInt(60));
      out.add(AppTransaction(
        amount: amount,
        type: TxType.expense,
        categoryId: byName[t.cat]?.id,
        merchant: merchant,
        date: d,
        source: k % 3 == 0 ? 'regex' : (k % 3 == 1 ? 'gemini' : 'manual'),
        confidence: k % 3 == 2 ? 1.0 : 0.8 + rnd.nextDouble() * 0.2,
        createdAt: d,
      ));
    }
    if (m > 0 || now.day >= 5) {
      final d = DateTime(base.year, base.month, 5, 9, 0);
      out.add(AppTransaction(
        amount: 15000000,
        type: TxType.income,
        categoryId: byName[kIncomeCategory]?.id,
        merchant: 'Lương tháng ${base.month}',
        date: d,
        source: 'manual',
        createdAt: d,
      ));
    }
  }
  return out;
}
