import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:receipt_tracker/data/models/transaction.dart';
import 'package:receipt_tracker/domain/extraction_pipeline.dart';
import 'package:receipt_tracker/domain/gemini_service.dart';
import 'package:receipt_tracker/domain/regex_parser.dart';

class _FakeGemini implements GeminiClient {
  _FakeGemini({this.error, this.result});
  final GeminiException? error;
  final GeminiExtraction? result;
  int calls = 0;

  @override
  Future<GeminiExtraction> extract(String text,
      {required List<String> categories, bool isMessage = false}) async {
    calls++;
    if (error != null) throw error!;
    return result!;
  }

  @override
  Future<String> analyze(String summaryJson) async => 'ok';
}

// Hóa đơn confidence thấp (không có từ khóa tổng) -> kích hoạt Gemini.
const _lowConfReceipt = 'Quan Com Tam Sai Gon\n05/03/2025\nCom suon  45.000d\nTra da  5.000d';
// Hóa đơn confidence cao -> không cần Gemini.
const _highConfReceipt =
    'CIRCLE K\nNgay: 05/03/2025 14:30\nSua tuoi x2 30.000\nTong cong 85.000';

ExtractionPipeline _pipe(_FakeGemini? g, {bool online = true, bool enhanced = false}) =>
    ExtractionPipeline(
      parser: const RegexParser(),
      isOnline: () async => online,
      gemini: g,
      aiEnhanced: enhanced,
      categoryNames: const ['Ăn uống', 'Khác'],
    );

void main() {
  group('ExtractionPipeline fallback', () {
    for (final kind in GeminiErrorKind.values) {
      test('Gemini lỗi $kind -> fallback regex, không crash', () async {
        final g = _FakeGemini(error: GeminiException(kind));
        final r = await _pipe(g).processReceipt(_lowConfReceipt);
        expect(g.calls, 1);
        expect(r.source, 'regex');
        expect(r.parsed.amount, 45000);
        expect(r.warning, isNotNull);
      });
    }

    test('Offline -> không gọi Gemini', () async {
      final g = _FakeGemini(result: const GeminiExtraction(amount: 1));
      final r = await _pipe(g, online: false).processReceipt(_lowConfReceipt);
      expect(g.calls, 0);
      expect(r.source, 'regex');
      expect(r.parsed.amount, 45000);
    });

    test('Không có API key (gemini == null) -> chỉ regex', () async {
      final r = await _pipe(null).processReceipt(_lowConfReceipt);
      expect(r.source, 'regex');
      expect(r.warning, isNull);
    });

    test('Confidence cao + AI nâng cao tắt -> không gọi Gemini', () async {
      final g = _FakeGemini(result: const GeminiExtraction(amount: 1));
      final r = await _pipe(g).processReceipt(_highConfReceipt);
      expect(g.calls, 0);
      expect(r.parsed.amount, 85000);
    });

    test('AI nâng cao bật -> gọi Gemini dù confidence cao', () async {
      final g = _FakeGemini(result: const GeminiExtraction(amount: 90000, merchant: 'Circle K VN'));
      final r = await _pipe(g, enhanced: true).processReceipt(_highConfReceipt);
      expect(g.calls, 1);
      expect(r.source, 'gemini');
      expect(r.parsed.amount, 90000);
      expect(r.parsed.merchant, 'Circle K VN');
    });

    test('Gemini thành công ghi đè kết quả regex', () async {
      final g = _FakeGemini(
          result: GeminiExtraction(
        amount: 50000,
        date: DateTime(2025, 3, 5),
        merchant: 'Cơm Tấm Sài Gòn',
        category: 'Ăn uống',
        type: TxType.expense,
      ));
      final r = await _pipe(g).processReceipt(_lowConfReceipt);
      expect(r.source, 'gemini');
      expect(r.parsed.amount, 50000);
      expect(r.categoryName, 'Ăn uống');
      expect(r.parsed.confidence, greaterThanOrEqualTo(0.9));
    });
  });

  group('GeminiService (HTTP mock)', () {
    GeminiService svc(http.Client c, {Duration? timeout}) => GeminiService(
          apiKey: 'k',
          model: 'test-model',
          client: c,
          timeout: timeout ?? const Duration(seconds: 5),
        );

    Future<GeminiErrorKind> kindOf(Future<dynamic> f) async {
      try {
        await f;
      } on GeminiException catch (e) {
        return e.kind;
      }
      fail('expected GeminiException');
    }

    test('401 -> unauthorized', () async {
      final s = svc(MockClient((_) async => http.Response('{}', 401)));
      expect(await kindOf(s.extract('x', categories: const [])), GeminiErrorKind.unauthorized);
    });

    test('429 -> rateLimited', () async {
      final s = svc(MockClient((_) async => http.Response('{}', 429)));
      expect(await kindOf(s.analyze('{}')), GeminiErrorKind.rateLimited);
    });

    test('timeout -> timeout', () async {
      final s = svc(
        MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          return http.Response('{}', 200);
        }),
        timeout: const Duration(milliseconds: 50),
      );
      expect(await kindOf(s.analyze('{}')), GeminiErrorKind.timeout);
    });

    test('JSON hỏng -> badResponse', () async {
      final body = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'không phải json'}
              ]
            }
          }
        ]
      });
      final s = svc(MockClient((_) async => http.Response(body, 200,
          headers: {'content-type': 'application/json; charset=utf-8'})));
      expect(await kindOf(s.extract('x', categories: const [])), GeminiErrorKind.badResponse);
    });

    test('200 hợp lệ -> parse đúng', () async {
      final inner = jsonEncode({
        'amount': 132000,
        'date': '2025-09-20',
        'merchant': 'Starbucks',
        'category': 'Ăn uống',
        'type': 'expense',
        'items': [
          {'name': 'Latte', 'qty': 2, 'price': 66000}
        ],
      });
      final body = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': inner}
              ]
            }
          }
        ]
      });
      final s = svc(MockClient((req) async {
        expect(req.headers['x-goog-api-key'], 'k');
        expect(req.url.path, contains('test-model:generateContent'));
        return http.Response(body, 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }));
      final e = await s.extract('x', categories: const ['Ăn uống', 'Khác']);
      expect(e.amount, 132000);
      expect(e.merchant, 'Starbucks');
      expect(e.category, 'Ăn uống');
      expect(e.date, DateTime(2025, 9, 20));
      expect(e.items.length, 1);
    });
  });
}
