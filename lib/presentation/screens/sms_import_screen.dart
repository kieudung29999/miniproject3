import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receipt_tracker/data/models/transaction.dart';
import 'package:receipt_tracker/domain/categorizer.dart';
import 'package:receipt_tracker/presentation/providers/providers.dart';
import 'package:receipt_tracker/presentation/screens/review_screen.dart';
import 'package:receipt_tracker/presentation/widgets/common.dart';

class SmsImportScreen extends ConsumerStatefulWidget {
  const SmsImportScreen({super.key, this.initialText});
  final String? initialText;

  @override
  ConsumerState<SmsImportScreen> createState() => _SmsImportScreenState();
}

class _SmsImportScreenState extends ConsumerState<SmsImportScreen> {
  late final TextEditingController _c = TextEditingController(text: widget.initialText ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text != null) setState(() => _c.text = d!.text!);
  }

  Future<void> _analyze() async {
    final text = _c.text.trim();
    if (text.isEmpty) {
      showSnack(context, 'Hãy dán nội dung tin nhắn trước.');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await ref.read(pipelineProvider).processMessage(text);
      final cats = await ref.read(categoriesProvider.future);
      final cat = Categorizer(cats).categorize(
        '${res.parsed.merchant ?? ''} $text',
        type: res.parsed.type,
        aiName: res.categoryName,
      );
      var warning = res.warning;
      if (res.parsed.amount == null) {
        warning = [warning, 'Không nhận diện được số tiền, hãy nhập tay.']
            .whereType<String>()
            .join('\n');
      }
      final now = DateTime.now();
      if (!mounted) return;
      final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => ReviewScreen(
          warning: warning,
          items: res.items,
          initial: AppTransaction(
            amount: res.parsed.amount ?? 0,
            type: res.parsed.type,
            categoryId: cat.id,
            merchant: res.parsed.merchant,
            note: null,
            date: res.parsed.date ?? now,
            source: res.source,
            rawText: text,
            confidence: res.parsed.confidence,
            createdAt: now,
          ),
        ),
      ));
      if (saved == true && mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showSnack(context, 'Lỗi xử lý tin nhắn: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nhập từ tin nhắn')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
              'Dán tin nhắn ngân hàng / biên lai / hợp đồng. Regex xử lý offline; Gemini hỗ trợ nếu mẫu lạ và có mạng.'),
          const SizedBox(height: 12),
          TextField(
            controller: _c,
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText: 'VD: TK 0011…456 -150,000 VND ND: Thanh toan tai CIRCLE K. So du: …',
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            OutlinedButton.icon(
                onPressed: _paste, icon: const Icon(Icons.content_paste), label: const Text('Dán')),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _analyze,
                icon: _busy
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_fix_high),
                label: const Text('Phân tích'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
