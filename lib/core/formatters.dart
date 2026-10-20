import 'package:intl/intl.dart';

String fmtMoney(num v) =>
    '${NumberFormat('#,##0', 'en_US').format(v.round()).replaceAll(',', '.')} ₫';

String fmtDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
String fmtDateTime(DateTime d) => DateFormat('dd/MM/yyyy HH:mm').format(d);
String fmtMonth(DateTime d) => DateFormat('MM/yyyy').format(d);
String monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);

String fmtCompact(double v) {
  if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(v >= 1e7 ? 0 : 1)}tr';
  if (v >= 1e3) return '${(v / 1e3).round()}k';
  return v.round().toString();
}
