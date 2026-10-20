import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receipt_tracker/domain/csv_exporter.dart';
import 'package:receipt_tracker/domain/seed_data.dart';
import 'package:receipt_tracker/presentation/providers/providers.dart';
import 'package:receipt_tracker/presentation/widgets/common.dart';
import 'package:share_plus/share_plus.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _key = TextEditingController();
  late final TextEditingController _model =
      TextEditingController(text: ref.read(settingsProvider).model);
  bool _obscure = true;

  static const _modelHints = ['gemini-2.5-flash', 'gemini-2.5-flash-lite', 'gemini-2.0-flash'];

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _exportCsv() async {
    try {
      final list = await ref.read(txRepoProvider).query();
      if (list.isEmpty) {
        if (mounted) showSnack(context, 'Chưa có dữ liệu để xuất.');
        return;
      }
      final cats = await ref.read(categoriesProvider.future);
      final csv = CsvExporter.build(list, {for (final c in cats) c.id!: c});
      final f = await CsvExporter.writeTemp(csv);
      await Share.shareXFiles([XFile(f.path)], text: 'Giao dịch Receipt & Expense Tracker');
    } catch (e) {
      if (mounted) showSnack(context, 'Xuất CSV thất bại: $e');
    }
  }

  Future<void> _seed() async {
    final cats = await ref.read(categoriesProvider.future);
    await ref.read(txRepoProvider).insertAll(generateDemoTransactions(cats));
    bumpData(ref);
    if (mounted) showSnack(context, 'Đã nạp dữ liệu demo.');
  }

  Future<void> _wipe() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa toàn bộ dữ liệu?'),
        content: const Text('Tất cả giao dịch và phân tích AI đã lưu sẽ bị xóa. Không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa hết')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(txRepoProvider).deleteAll();
    await ref.read(insightRepoProvider).deleteAll();
    bumpData(ref);
    if (mounted) showSnack(context, 'Đã xóa dữ liệu.');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = ref.watch(settingsProvider);
    ref.listen(settingsProvider, (prev, next) {
      if (prev != null && !prev.loaded && next.loaded) _model.text = next.model;
    });
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, kNavSpace),
        children: [
          AppCard(
            radius: 24,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.auto_awesome),
                const SizedBox(width: 8),
                Text('Gemini AI',
                    style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                Chip(
                  label: Text(s.hasKey ? 'Đã có API key' : 'Chưa có key'),
                  visualDensity: VisualDensity.compact,
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                'Key được lưu mã hóa trên máy (flutter_secure_storage), không nằm trong mã nguồn/APK.',
                style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _key,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: s.hasKey ? 'Nhập key mới để thay thế' : 'Gemini API key',
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      if (_key.text.trim().isEmpty) {
                        showSnack(context, 'Hãy nhập API key.');
                        return;
                      }
                      await notifier.setApiKey(_key.text);
                      _key.clear();
                      if (mounted) showSnack(context, 'Đã lưu API key.');
                    },
                    child: const Text('Lưu key'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: s.hasKey
                      ? () async {
                          await notifier.clearApiKey();
                          if (mounted) showSnack(context, 'Đã xóa API key.');
                        }
                      : null,
                  child: const Text('Xóa key'),
                ),
              ]),
              const SizedBox(height: 16),
              TextField(
                controller: _model,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Model Gemini',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () async {
                      await notifier.setModel(_model.text);
                      _model.text = ref.read(settingsProvider).model;
                      if (mounted) showSnack(context, 'Đã lưu model.');
                    },
                  ),
                ),
                onSubmitted: (v) => notifier.setModel(v),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final m in _modelHints)
                  ActionChip(
                    label: Text(m, style: const TextStyle(fontSize: 11)),
                    onPressed: () {
                      _model.text = m;
                      notifier.setModel(m);
                    },
                  ),
              ]),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('AI nâng cao'),
                subtitle: const Text('Luôn dùng Gemini khi có mạng (không chỉ khi độ tin cậy thấp).'),
                value: s.aiEnhanced && s.hasKey,
                onChanged: s.hasKey ? notifier.setAiEnhanced : null,
              ),
            ]),
          ),
          const SizedBox(height: 16),
          AppCard(
            radius: 24,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Giao diện',
                  style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('Hệ thống'), icon: Icon(Icons.phone_android)),
                  ButtonSegment(value: ThemeMode.light, label: Text('Sáng'), icon: Icon(Icons.light_mode)),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Tối'), icon: Icon(Icons.dark_mode)),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) => notifier.setThemeMode(v.first),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          AppCard(
            radius: 24,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.ios_share),
                title: const Text('Xuất CSV'),
                subtitle: const Text('Chia sẻ toàn bộ giao dịch (mở được bằng Excel).'),
                onTap: _exportCsv,
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome_motion),
                title: const Text('Nạp dữ liệu demo'),
                subtitle: const Text('Thêm ~50 giao dịch mẫu để thử biểu đồ.'),
                onTap: _seed,
              ),
              ListTile(
                leading: Icon(Icons.delete_forever, color: Colors.red.shade400),
                title: Text('Xóa toàn bộ dữ liệu', style: TextStyle(color: Colors.red.shade400)),
                onTap: _wipe,
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
