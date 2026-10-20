import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tracker/data/models/transaction.dart';
import 'package:receipt_tracker/domain/regex_parser.dart';

void main() {
  const parser = RegexParser();

  group('parseMoney', () {
    test('dấu chấm phân cách nghìn', () => expect(RegexParser.parseMoney('1.250.000'), 1250000));
    test('dấu phẩy phân cách nghìn', () => expect(RegexParser.parseMoney('70,000'), 70000));
    test('có phần thập phân', () => expect(RegexParser.parseMoney('250.000,00'), 250000));
    test('kiểu Mỹ có thập phân', () => expect(RegexParser.parseMoney('1,250,000.50'), 1250000));
    test('số liền', () => expect(RegexParser.parseMoney('150000'), 150000));
  });

  group('hóa đơn', () {
    test('1. Circle K: tổng cộng + tiền khách đưa/tiền thừa', () {
      final r = parser.parseReceipt('''
CIRCLE K
Dia chi: 123 Nguyen Hue, Q1
Ngay: 05/03/2025 14:30
Sua tuoi x2   30.000
Tong cong   85.000
Tien khach dua 100.000
Tien thua 15.000
''');
      expect(r.amount, 85000);
      expect(r.merchant, 'CIRCLE K');
      expect(r.date?.day, 5);
      expect(r.date?.month, 3);
      expect(r.date?.year, 2025);
      expect(r.date?.hour, 14);
      expect(r.confidence, greaterThanOrEqualTo(0.7));
    });

    test('2. Highlands: TONG TIEN dấu phẩy + VND', () {
      final r = parser.parseReceipt('''
HIGHLANDS COFFEE
HOA DON THANH TOAN
01/10/2025 08:15
1 Cafe sua da 45.000
1 Banh mi 25.000
TONG TIEN: 70,000 VND
''');
      expect(r.amount, 70000);
      expect(r.merchant, 'HIGHLANDS COFFEE');
      expect(r.date?.month, 10);
    });

    test('3. Tổng nằm ở dòng kế tiếp', () {
      final r = parser.parseReceipt('Winmart+\nNgay 12/11/2025\nTONG CONG\n1.250.000');
      expect(r.amount, 1250000);
      expect(r.date?.day, 12);
    });

    test('4. Hóa đơn tiếng Anh: bỏ qua subtotal/VAT', () {
      final r = parser.parseReceipt('''
STARBUCKS
Date: 20/09/2025
Subtotal 120,000
VAT 10% 12,000
Total 132,000
''');
      expect(r.amount, 132000);
      expect(r.merchant, 'STARBUCKS');
    });

    test('5. Không có từ khóa tổng -> lấy số có đơn vị tiền, confidence thấp', () {
      final r = parser.parseReceipt('''
Quan Com Tam Sai Gon
05/03/2025
Com suon  45.000d
Tra da  5.000d
''');
      expect(r.amount, 45000);
      expect(r.confidence, lessThan(0.7));
    });

    test('6. OCR rác, không có số tiền -> amount null, không throw', () {
      final r = parser.parseReceipt('Cam on quy khach\nHen gap lai');
      expect(r.amount, isNull);
    });

    test('7. Có dấu tiếng Việt: Tổng cộng ... đ', () {
      final r = parser.parseReceipt('Nhà hàng: Phở 24\nTỔNG CỘNG: 2.350.000 đ');
      expect(r.amount, 2350000);
      expect(r.merchant, 'Phở 24');
    });

    test('8. Thành tiền', () {
      expect(parser.parseReceipt('Cua hang ABC\nThành tiền: 99.000').amount, 99000);
    });

    test('9. Phải trả', () {
      expect(parser.parseReceipt('Phải trả 560.000').amount, 560000);
    });

    test('10. Chọn tổng thanh toán thay vì tổng tiền hàng', () {
      final r = parser.parseReceipt('Tong tien hang 120.000\nTong thanh toan 132.000');
      expect(r.amount, 132000);
    });

    test('11. Chuỗi rỗng không crash', () {
      final r = parser.parseReceipt('');
      expect(r.amount, isNull);
      expect(r.confidence, 0);
    });
  });

  group('tin nhắn ngân hàng', () {
    test('12. Trừ tiền (-): bỏ qua số dư, lấy merchant sau "tai"', () {
      final r = parser.parseSms(
          'VCB 05/03/25 14:30 TK 0011004123456 -150,000 VND ND: Thanh toan tai CIRCLE K. So du: 5,250,000 VND');
      expect(r.amount, 150000);
      expect(r.type, TxType.expense);
      expect(r.merchant, 'CIRCLE K');
      expect(r.date?.day, 5);
      expect(r.date?.year, 2025);
    });

    test('13. Cộng tiền (+): income', () {
      final r = parser.parseSms(
          'TK 1234567890 +5,000,000 VND luc 12:00 01/10/2025. ND: LUONG THANG 9. SD: 7,500,000');
      expect(r.amount, 5000000);
      expect(r.type, TxType.income);
      expect(r.date?.month, 10);
    });

    test('14. Viết tắt 50k, suy ra chi', () {
      final r = parser.parseSms('Chi tieu 50k tai Grab');
      expect(r.amount, 50000);
      expect(r.type, TxType.expense);
    });

    test('15. Không dấu +/-: "nhận được" -> income', () {
      final r = parser.parseSms('Ban da nhan duoc 2.000.000d tu NGUYEN VAN A');
      expect(r.amount, 2000000);
      expect(r.type, TxType.income);
    });

    test('16. Rỗng không crash', () {
      expect(parser.parseSms('   ').amount, isNull);
    });
  });
}
