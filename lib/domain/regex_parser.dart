import 'dart:math';

import 'package:receipt_tracker/core/text_utils.dart';
import 'package:receipt_tracker/data/models/transaction.dart';

class ParsedTransaction {
  const ParsedTransaction({
    this.amount,
    this.date,
    this.merchant,
    this.type = TxType.expense,
    this.confidence = 0,
    this.amountFromKeyword = false,
  });

  final double? amount;
  final DateTime? date;
  final String? merchant;
  final TxType type;
  final double confidence;
  final bool amountFromKeyword;
}

/// Parser offline cho hóa đơn / tin nhắn ngân hàng tiếng Việt.
/// Luôn trả về kết quả (có thể amount == null) và không bao giờ throw.
class RegexParser {
  const RegexParser();

  // Thứ tự = độ ưu tiên (đứng trước = mạnh hơn). Đã bỏ dấu, lowercase.
  static const _totalKeywords = <String>[
    'tong cong thanh toan',
    'tong tien thanh toan',
    'tong thanh toan',
    'tong cong',
    'tong tien',
    'tong so tien',
    'phai thanh toan',
    'phai tra',
    'phai thu',
    'grand total',
    'total amount',
    'amount due',
    'total',
    'thanh tien',
    'thanh toan',
  ];

  static final _exclude = RegExp(
      r'tien khach|khach dua|khach tra|tien thua|tien thoi|tra lai|change|cash|giam gia|discount|\bvat\b|thue|diem|sub ?total|tam tinh|so du|chiet khau');

  static const _moneyPat =
      r'\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?';
  static final _money = RegExp(r'(?<![\d.,])(' + _moneyPat + r')(?!\d)');
  static final _curMoney =
      RegExp(r'(?<![\d.,])(' + _moneyPat + r')\s*(?:d|vnd|dong|₫)(?![a-z])');
  static final _kwMoney = RegExp(
      r'(?:so tien|giao dich|\bgd\b|thanh toan|amount|tien)[^0-9]{0,15}(' +
          _moneyPat +
          r')(?!\d)');
  static final _shortMoney =
      RegExp(r'(?<![\d.,])(\d+(?:[.,]\d+)?)\s*(k|tr|trieu|m)(?![a-z])');
  static final _signed =
      RegExp(r'(?<!\w)([+-])\s?(\d{1,3}(?:[.,]\d{3})+|\d{4,})(?!\d)');
  static final _balance = RegExp(
      r'(?<![a-z])(?:so du|sd|balance|bal)(?![a-z])[^0-9\n]{0,15}[+-]?\s*\d[\d.,]*(?:\s*(?:vnd|d|dong))?');

  static final _scrubPatterns = <RegExp>[
    RegExp(r'(?<![\d.,])\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4}(?!\d)'),
    RegExp(r'(?<!\d)\d{4}[/\-]\d{1,2}[/\-]\d{1,2}(?!\d)'),
    RegExp(r'\d{1,2}:\d{2}(?::\d{2})?'),
    RegExp(r'\d{9,}'),
  ];

  static final _dateYmd =
      RegExp(r'(?<!\d)(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})(?!\d)');
  static final _dateDmy =
      RegExp(r'(?<![\d.,])(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4}|\d{2})(?!\d)');
  static final _dateWords =
      RegExp(r'ngay\s*(\d{1,2})\s*thang\s*(\d{1,2})\s*nam\s*(\d{4})');
  static final _timeTail = RegExp(r'^[\s,\-]*(?:luc\s*)?(\d{1,2}):(\d{2})');

  static final _merchantLabel = RegExp(
      r'(?:ten cua hang|cua hang|merchant|store|nha hang|don vi ban hang|ten don vi)\s*[:\-]\s*(.+)');
  static final _merchantSkip = RegExp(
      r'hoa don|phieu|receipt|invoice|dia chi|hotline|\bsdt\b|\btel\b|\bmst\b|ma so thue|www\.|http|\.com|\.vn|thu ngan|cashier|kinh chao|cam on|^ngay|so hd|\bdt\b|\bdc\b|^\s*(?:ban|ma)\b');

  static final _smsMerchantAt =
      RegExp(r'(?<![a-z])(?:tai|at)(?![a-z])\s*[:\-]?\s*([^.;,\n]{3,40})');
  static final _smsMerchantNd = RegExp(
      r'(?<![a-z])(?:noi dung|nd|content)(?![a-z])\s*[:\-]?\s*([^.;,\n]{3,40})');

  static const _incomeWords = <String>[
    'nhan duoc',
    'da nhan',
    'ghi co',
    'credit',
    'cong tien',
    'tien vao',
    'hoan tien',
    'luong',
    'chuyen den',
    'nhan tien',
  ];
  static const _expenseWords = <String>[
    'ghi no',
    'debit',
    'thanh toan',
    'giao dich the',
    'mua',
    'rut',
    'chi tieu',
    'tru tien',
    'payment',
    'chuyen khoan den',
    'chuyen tien den',
  ];

  // ---------------------------------------------------------------- public

  /// "1.250.000" | "70,000" | "250.000,00" -> số VND.
  static double? parseMoney(String token) {
    var s = token.trim();
    final dec = RegExp(r'^(.*\d{3})[.,]\d{1,2}$').firstMatch(s);
    if (dec != null) {
      s = dec.group(1)!;
    } else {
      final d2 = RegExp(r'^(\d+)[.,]\d{1,2}$').firstMatch(s);
      if (d2 != null) s = d2.group(1)!;
    }
    s = s.replaceAll(RegExp(r'[.,]'), '');
    return double.tryParse(s);
  }

  ParsedTransaction parseReceipt(String text) {
    try {
      final raw = text
          .split(RegExp(r'[\r\n]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (raw.isEmpty) return const ParsedTransaction();
      final norm = raw.map(removeDiacritics).toList();
      final scrub = norm.map(_scrub).toList();

      final (amount, viaKeyword) = _findAmount(scrub);
      final date = _findDate(norm.join('\n'));
      final merchant = _findMerchant(raw, norm);

      var conf = 0.0;
      if (amount != null) conf += viaKeyword ? 0.55 : 0.25;
      if (date != null) conf += 0.2;
      if (merchant != null) conf += 0.2;
      return ParsedTransaction(
        amount: amount,
        date: date,
        merchant: merchant,
        type: TxType.expense,
        confidence: min(conf, 1.0),
        amountFromKeyword: viaKeyword,
      );
    } catch (_) {
      return const ParsedTransaction();
    }
  }

  ParsedTransaction parseSms(String text) {
    try {
      final raw = text.trim();
      if (raw.isEmpty) return const ParsedTransaction();
      final norm = removeDiacritics(raw);
      final noBal = norm.replaceAll(_balance, ' ');

      double? amount;
      var viaSign = false;
      var signIncome = false;

      final sm = _signed.firstMatch(noBal);
      if (sm != null) {
        amount = _valid(parseMoney(sm.group(2)!));
        if (amount != null) {
          viaSign = true;
          signIncome = sm.group(1) == '+';
        }
      }
      final s2 = _scrub(noBal);
      if (amount == null) {
        final m = _shortMoney.firstMatch(s2);
        if (m != null) {
          final n = double.tryParse(m.group(1)!.replaceAll(',', '.'));
          if (n != null)
            amount = _valid(n * (m.group(2) == 'k' ? 1000 : 1000000));
        }
      }
      if (amount == null) {
        final m = _curMoney.firstMatch(s2);
        if (m != null) amount = _valid(parseMoney(m.group(1)!));
      }
      if (amount == null) {
        final m = _kwMoney.firstMatch(s2);
        if (m != null) amount = _valid(parseMoney(m.group(1)!));
      }

      TxType type;
      var typeCertain = false;
      if (viaSign) {
        type = signIncome ? TxType.income : TxType.expense;
        typeCertain = true;
      } else {
        final inc = _incomeWords.where((w) => _hasWord(norm, w)).length;
        final exp = _expenseWords.where((w) => _hasWord(norm, w)).length;
        type = inc > exp ? TxType.income : TxType.expense;
        typeCertain = inc != exp;
      }

      final date = _findDate(norm);

      String? merchant;
      for (final re in [_smsMerchantAt, _smsMerchantNd]) {
        final m = re.firstMatch(norm);
        if (m != null && m.group(1) != null) {
          final v = m.group(1)!.trim();
          if (v.length >= 2) {
            merchant = _clip(v);
            break;
          }
        }
      }

      var conf = 0.0;
      if (amount != null) conf += viaSign ? 0.6 : 0.45;
      if (date != null) conf += 0.15;
      if (merchant != null) conf += 0.15;
      if (typeCertain) conf += 0.1;
      return ParsedTransaction(
        amount: amount,
        date: date,
        merchant: merchant,
        type: type,
        confidence: min(conf, 1.0),
        amountFromKeyword: amount != null,
      );
    } catch (_) {
      return const ParsedTransaction();
    }
  }

  // --------------------------------------------------------------- helpers

  static double? _valid(double? v) =>
      (v != null && v >= 1000 && v < 1e11) ? v : null;

  static bool _hasWord(String s, String w) =>
      RegExp('(?<![a-z])${RegExp.escape(w)}(?![a-z])').hasMatch(s);

  static String _scrub(String s) {
    var o = s;
    for (final p in _scrubPatterns) {
      o = o.replaceAll(p, ' ');
    }
    return o;
  }

  static String _clip(String s) => s.length > 60 ? s.substring(0, 60) : s;

  static List<double> _moneyIn(String s) {
    final out = <double>[];
    for (final m in _money.allMatches(s)) {
      final v = parseMoney(m.group(1)!);
      if (v != null && v >= 1000 && v < 1e10) out.add(v);
    }
    return out;
  }

  (double?, bool) _findAmount(List<String> lines) {
    final cands = <(int, double)>[];
    for (var i = 0; i < lines.length; i++) {
      final n = lines[i];
      if (!n.contains('tong') && _exclude.hasMatch(n)) continue;
      for (var k = 0; k < _totalKeywords.length; k++) {
        final kw = _totalKeywords[k];
        final idx = n.indexOf(kw);
        if (idx < 0) continue;
        var vals = _moneyIn(n.substring(idx + kw.length));
        final strong = kw.startsWith('tong') ||
            kw.contains('total') ||
            kw.startsWith('phai') ||
            kw.contains('amount');
        if (vals.isEmpty &&
            strong &&
            i + 1 < lines.length &&
            !_exclude.hasMatch(lines[i + 1])) {
          vals = _moneyIn(lines[i + 1]);
        }
        if (vals.isNotEmpty) cands.add((k, vals.reduce(max)));
        break;
      }
    }
    if (cands.isNotEmpty) {
      cands.sort((a, b) {
        final c = a.$1.compareTo(b.$1);
        return c != 0 ? c : b.$2.compareTo(a.$2);
      });
      return (cands.first.$2, true);
    }
    // Fallback: số có đơn vị tiền tệ, rồi số lớn nhất.
    final withCur = <double>[];
    final all = <double>[];
    for (final n in lines) {
      for (final m in _curMoney.allMatches(n)) {
        final v = parseMoney(m.group(1)!);
        if (v != null && v >= 1000 && v < 1e10) withCur.add(v);
      }
      all.addAll(_moneyIn(n));
    }
    if (withCur.isNotEmpty) return (withCur.reduce(max), false);
    if (all.isNotEmpty) return (all.reduce(max), false);
    return (null, false);
  }

  DateTime? _findDate(String s) {
    final limit = DateTime.now().add(const Duration(days: 1));

    DateTime? mk(int y, int m, int d, int end) {
      if (y < 100) y += 2000;
      if (y < 2000 || m < 1 || m > 12 || d < 1 || d > 31) return null;
      var h = 0, mi = 0;
      final tail = s.substring(end, min(s.length, end + 14));
      final tm = _timeTail.firstMatch(tail);
      if (tm != null) {
        h = int.parse(tm.group(1)!);
        mi = int.parse(tm.group(2)!);
        if (h > 23 || mi > 59) {
          h = 0;
          mi = 0;
        }
      }
      final dt = DateTime(y, m, d, h, mi);
      if (dt.month != m || dt.isAfter(limit)) return null;
      return dt;
    }

    for (final x in _dateYmd.allMatches(s)) {
      final r = mk(int.parse(x.group(1)!), int.parse(x.group(2)!),
          int.parse(x.group(3)!), x.end);
      if (r != null) return r;
    }
    for (final x in _dateDmy.allMatches(s)) {
      final r = mk(int.parse(x.group(3)!), int.parse(x.group(2)!),
          int.parse(x.group(1)!), x.end);
      if (r != null) return r;
    }
    for (final x in _dateWords.allMatches(s)) {
      final r = mk(int.parse(x.group(3)!), int.parse(x.group(2)!),
          int.parse(x.group(1)!), x.end);
      if (r != null) return r;
    }
    return null;
  }

  String? _findMerchant(List<String> raw, List<String> norm) {
    for (var i = 0; i < norm.length; i++) {
      final m = _merchantLabel.firstMatch(norm[i]);
      if (m != null && m.group(1) != null) {
        final v = m.group(1)!.trim();
        if (v.length >= 2) return _clip(v);
      }
    }
    for (var i = 0; i < norm.length && i < 8; i++) {
      final n = norm[i];
      if (_merchantSkip.hasMatch(n)) continue;
      final letters = RegExp(r'[a-z]').allMatches(n).length;
      final digits = RegExp(r'\d').allMatches(n).length;
      if (letters < 3 || digits > letters) continue;
      return _clip(raw[i]);
    }
    return null;
  }
}
