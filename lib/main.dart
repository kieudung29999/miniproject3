import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receipt_tracker/core/theme.dart';
import 'package:receipt_tracker/presentation/providers/providers.dart';
import 'package:receipt_tracker/presentation/screens/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ReceiptTrackerApp()));
}

class ReceiptTrackerApp extends ConsumerWidget {
  const ReceiptTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp(
      title: 'Receipt & Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      home: const HomeShell(),
    );
  }
}
