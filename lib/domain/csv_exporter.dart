import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:receipt_tracker/data/models/category.dart';
import 'package:receipt_tracker/data/models/transaction.dart';

class CsvExporter {
  static String build(List<AppTransaction> list, Map<int, Category> cats) {
    final b = StringBuffer('\uFEFF'); // BOM để Excel đọc đúng tiếng Việt
    b.writeln('id,ngay,loai,so_tien,danh_muc,cua_hang,ghi_chu,nguon,do_tin_cay');
    final df = DateFormat('yyyy-MM-dd HH:mm');
    for (final t in list) {
      b.writeln([
        t.id,
        df.format(t.date),
        t.type == TxType.expense ? 'chi' : 'thu',
        t.amount.round(),
        cats[t.categoryId]?.name ?? '',
        t.merchant ?? '',
        t.note ?? '',
        t.source,
        t.confidence.toStringAsFixed(2),
      ].map(_q).join(','));
    }
    return b.toString();
  }

  static String _q(Object? v) {
    final s = '${v ?? ''}';
    return (s.contains(',') || s.contains('"') || s.contains('\n'))
        ? '"${s.replaceAll('"', '""')}"'
        : s;
  }

  static Future<File> writeTemp(String csv) async {
    final dir = await getTemporaryDirectory();
    final name = 'expenses_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    return File(p.join(dir.path, name)).writeAsString(csv, flush: true);
  }
}
