import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receipt_tracker/core/constants.dart';
import 'package:receipt_tracker/core/formatters.dart';
import 'package:receipt_tracker/data/models/category.dart';
import 'package:receipt_tracker/data/models/transaction.dart';
import 'package:receipt_tracker/presentation/providers/providers.dart';
import 'package:receipt_tracker/presentation/widgets/common.dart';

/// Màn Review & sửa tay: dùng cho giao dịch mới (từ OCR/SMS/thủ công) và sửa giao dịch cũ.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({
    super.key,
    required this.initial,
    this.warning,
    this.items = const [],
  });

  final AppTransaction initial;
  final String? warning;
  final List<Map<String, dynamic>> items;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  late final TextEditingController _amount = TextEditingController(
      text: widget.initial.amount > 0 ? widget.initial.amount.round().toString() : '');
  late final TextEditingController _merchant =
      TextEditingController(text: widget.initial.merchant ?? '');
  late final TextEditingController _note = TextEditingController(text: widget.initial.note ?? '');
  late TxType _type = widget.initial.type;
  late int? _catId = widget.initial.categoryId;
  late DateTime _date = widget.initial.date;

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _note.dispose();
    super.dispose();
  }

  Category? _byName(List<Category> cats, String name) {
    for (final c in cats) {
      if (c.name == name) return c;
    }
    return null;
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) {
      setState(() => _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute));
    }
  }

  Future<void> _save() async {
    final i = widget.initial;
    final amt = double.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (amt == null || amt <= 0) {
      showSnack(context, 'Hãy nhập số tiền hợp lệ.');
      return;
    }
    final merchant = _merchant.text.trim();
    final note = _note.text.trim();
    var source = i.source;
    final changed = amt != i.amount ||
        merchant != (i.merchant ?? '') ||
        _date != i.date ||
        _type != i.type;
    if (source != 'manual' && changed) source = 'manual';

    final t = AppTransaction(
      id: i.id,
      amount: amt,
      type: _type,
      categoryId: _catId,
      merchant: merchant.isEmpty ? null : merchant,
      note: note.isEmpty ? null : note,
      date: _date,
      source: source,
      imagePath: i.imagePath,
      rawText: i.rawText,
      confidence: i.confidence,
      createdAt: i.createdAt,
    );
    final repo = ref.read(txRepoProvider);
    if (i.id == null) {
      await repo.insert(t);
    } else {
      await repo.update(t);
    }
    bumpData(ref);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa giao dịch?'),
        content: const Text('Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(txRepoProvider).delete(widget.initial.id!);
    bumpData(ref);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final i = widget.initial;
    final cats = ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    final hasImage = i.imagePath != null && File(i.imagePath!).existsSync();
    final conf = i.confidence;
    final confColor = conf >= 0.7 ? AppColors.good : (conf >= 0.4 ? Colors.orange : AppColors.bad);

    return Scaffold(
      appBar: AppBar(
        title: Text(i.id == null ? 'Xác nhận giao dịch' : 'Sửa giao dịch'),
        actions: [
          if (i.id != null)
            IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          if (widget.warning != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline, size: 18, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(child: Text(widget.warning!)),
              ]),
            ),
          if (hasImage)
            GestureDetector(
              onTap: () => showFullImage(context, i.imagePath!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(File(i.imagePath!), height: 200, width: double.infinity, fit: BoxFit.cover),
              ),
            ),
          if (hasImage) const SizedBox(height: 12),
          if (i.id != null || i.source != 'manual')
            Row(children: [
              Chip(
                avatar: Icon(Icons.speed, size: 16, color: confColor),
                label: Text('Độ tin cậy ${(conf * 100).round()}%'),
              ),
              const SizedBox(width: 8),
              Chip(
                avatar: const Icon(Icons.memory, size: 16),
                label: Text('Nguồn: ${i.source}'),
              ),
            ]),
          const SizedBox(height: 8),
          SegmentedButton<TxType>(
            segments: const [
              ButtonSegment(value: TxType.expense, label: Text('Chi (-)'), icon: Icon(Icons.remove)),
              ButtonSegment(value: TxType.income, label: Text('Thu (+)'), icon: Icon(Icons.add)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              if (_type == TxType.income) {
                _catId = _byName(cats, kIncomeCategory)?.id ?? _catId;
              } else if (_catId == _byName(cats, kIncomeCategory)?.id) {
                _catId = _byName(cats, kOtherCategory)?.id;
              }
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            decoration: const InputDecoration(labelText: 'Số tiền', suffixText: '₫'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _merchant,
            decoration: const InputDecoration(labelText: 'Cửa hàng / nội dung'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: cats.any((c) => c.id == _catId) ? _catId : null,
            decoration: const InputDecoration(labelText: 'Danh mục'),
            items: [
              for (final c in cats)
                DropdownMenuItem(
                  value: c.id,
                  child: Row(children: [
                    Icon(c.iconData, size: 18, color: c.colorValue),
                    const SizedBox(width: 8),
                    Text(c.name),
                  ]),
                ),
            ],
            onChanged: (v) => setState(() => _catId = v),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Ngày'),
              child: Row(children: [
                const Icon(Icons.calendar_today, size: 18),
                const SizedBox(width: 8),
                Text(fmtDate(_date)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Ghi chú'),
          ),
          if (widget.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text('Mặt hàng (AI nhận diện)'),
              children: [
                for (final it in widget.items)
                  ListTile(
                    dense: true,
                    title: Text('${it['name'] ?? ''}'),
                    trailing: Text('${it['qty'] ?? ''} × ${it['price'] ?? ''}'),
                  ),
              ],
            ),
          ],
          if ((i.rawText ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            ExpansionTile(
              title: const Text('Văn bản gốc (OCR)'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(i.rawText!, style: t.textTheme.bodySmall),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: Text(i.id == null ? 'Lưu giao dịch' : 'Cập nhật'),
          ),
        ],
      ),
    );
  }
}
