import 'package:flutter/material.dart';
import 'package:receipt_tracker/core/constants.dart';
import 'package:receipt_tracker/presentation/screens/dashboard_screen.dart';
import 'package:receipt_tracker/presentation/screens/scan_screen.dart';
import 'package:receipt_tracker/presentation/screens/settings_screen.dart';
import 'package:receipt_tracker/presentation/screens/stats_screen.dart';
import 'package:receipt_tracker/presentation/screens/transactions_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _i = 0;

  static const _items = <(IconData, String)>[
    (Icons.dashboard_rounded, 'Tổng quan'),
    (Icons.receipt_long_rounded, 'Giao dịch'),
    (Icons.document_scanner_rounded, 'Quét'),
    (Icons.pie_chart_rounded, 'Thống kê'),
    (Icons.settings_rounded, 'Cài đặt'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _i,
            children: const [
              DashboardScreen(),
              TransactionsScreen(),
              ScanScreen(),
              StatsScreen(),
              SettingsScreen(),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: SafeArea(top: false, child: _nav(context)),
          ),
        ],
      ),
    );
  }

  Widget _nav(BuildContext context) {
    final t = Theme.of(context);
    final dark = t.brightness == Brightness.dark;
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1F2E21) : Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < _items.length; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _i = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                padding: EdgeInsets.symmetric(horizontal: _i == i ? 14 : 10, vertical: 10),
                decoration: BoxDecoration(
                  color: _i == i ? AppColors.lime : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_items[i].$1,
                      size: 24,
                      color: _i == i ? AppColors.green : t.colorScheme.onSurfaceVariant),
                  if (_i == i) ...[
                    const SizedBox(width: 6),
                    Text(_items[i].$2,
                        style: const TextStyle(
                            color: AppColors.green, fontWeight: FontWeight.w800, fontSize: 12)),
                  ],
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
