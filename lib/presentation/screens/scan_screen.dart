import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:receipt_tracker/data/models/transaction.dart';
import 'package:receipt_tracker/domain/categorizer.dart';
import 'package:receipt_tracker/presentation/providers/providers.dart';
import 'package:receipt_tracker/presentation/screens/review_screen.dart';
import 'package:receipt_tracker/presentation/widgets/common.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});
  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  bool _busy = false;
  String _status = '';

  Future<String> _persist(String srcPath) async {
    final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'receipts'));
    await dir.create(recursive: true);
    final dest = p.join(dir.path, 'r_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await File(srcPath).copy(dest);
    return dest;
  }

  Future<void> _permissionDialog(bool permanent) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cần quyền camera'),
        content: Text(permanent
            ? 'Quyền camera đã bị từ chối vĩnh viễn. Hãy bật lại trong Cài đặt hệ thống, hoặc chọn ảnh từ thư viện.'
            : 'Ứng dụng cần quyền camera để chụp hóa đơn. Bạn vẫn có thể chọn ảnh từ thư viện.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
          if (permanent)
            FilledButton(
              onPressed: () {
                openAppSettings();
                Navigator.pop(ctx);
              },
              child: const Text('Mở cài đặt'),
            ),
        ],
      ),
    );
  }

  Future<void> _start(ImageSource src) async {
    if (_busy) return;
    if (src == ImageSource.camera) {
      final st = await Permission.camera.request();
      if (!st.isGranted) {
        if (mounted) await _permissionDialog(st.isPermanentlyDenied);
        return;
      }
    }
    XFile? x;
    try {
      x = await ImagePicker().pickImage(source: src, imageQuality: 85, maxWidth: 2000);
    } catch (e) {
      if (mounted) showSnack(context, 'Không mở được ${src == ImageSource.camera ? 'camera' : 'thư viện'}.');
      return;
    }
    if (x == null) return;

    setState(() {
      _busy = true;
      _status = 'Đang đọc chữ (OCR offline)…';
    });
    try {
      final saved = await _persist(x.path);
      var raw = '';
      try {
        raw = await ref.read(ocrServiceProvider).recognize(saved);
      } catch (_) {
        raw = '';
      }
      final now = DateTime.now();
      final cats = await ref.read(categoriesProvider.future);

      if (raw.isEmpty) {
        if (!mounted) return;
        showSnack(context, 'Không đọc được chữ trên ảnh. Hãy nhập tay.');
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ReviewScreen(
            warning: 'OCR không đọc được nội dung. Vui lòng nhập thông tin thủ công.',
            initial: AppTransaction(
              amount: 0,
              type: TxType.expense,
              categoryId: Categorizer(cats).categorize('').id,
              date: now,
              source: 'manual',
              imagePath: saved,
              confidence: 0,
              createdAt: now,
            ),
          ),
        ));
        return;
      }

      if (mounted) setState(() => _status = 'Đang trích xuất thông tin…');
      final res = await ref.read(pipelineProvider).processReceipt(raw);
      final cat = Categorizer(cats).categorize(
        '${res.parsed.merchant ?? ''} $raw',
        type: res.parsed.type,
        aiName: res.categoryName,
      );
      var warning = res.warning;
      if (res.parsed.amount == null) {
        warning = [warning, 'Không tìm thấy tổng tiền, hãy nhập tay.']
            .whereType<String>()
            .join('\n');
      }
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ReviewScreen(
          warning: warning,
          items: res.items,
          initial: AppTransaction(
            amount: res.parsed.amount ?? 0,
            type: res.parsed.type,
            categoryId: cat.id,
            merchant: res.parsed.merchant,
            date: res.parsed.date ?? now,
            source: res.source,
            imagePath: saved,
            rawText: raw,
            confidence: res.parsed.confidence,
            createdAt: now,
          ),
        ),
      ));
    } catch (e) {
      if (mounted) showSnack(context, 'Có lỗi khi xử lý ảnh: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final online = ref.watch(onlineProvider).valueOrNull ?? false;
    final aiOn = settings.hasKey && online;

    return Scaffold(
      appBar: AppBar(title: const Text('Quét hóa đơn')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, kNavSpace),
        child: _busy
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_status),
                ]),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    radius: 28,
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      CircleAvatar(
                        radius: 38,
                        backgroundColor: t.colorScheme.secondary.withOpacity(0.35),
                        child: Icon(Icons.document_scanner_rounded,
                            size: 38, color: t.colorScheme.primary),
                      ),
                      const SizedBox(height: 16),
                      Text('Chụp hoặc chọn ảnh hóa đơn',
                          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(
                        aiOn
                            ? 'OCR chạy trên máy. AI Gemini sẽ hỗ trợ khi độ tin cậy thấp${settings.aiEnhanced ? ' (AI nâng cao: luôn bật)' : ''}.'
                            : 'OCR + regex chạy hoàn toàn offline. Thêm API key trong Cài đặt để bật AI khi có mạng.',
                        textAlign: TextAlign.center,
                        style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => _start(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('Chụp ảnh'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => _start(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Chọn từ thư viện'),
                      ),
                    ]),
                  ),
                ],
              ),
      ),
    );
  }
}
