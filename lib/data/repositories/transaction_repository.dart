import 'package:receipt_tracker/data/db/app_database.dart';
import 'package:receipt_tracker/data/models/transaction.dart';
import 'package:sqflite/sqflite.dart';

class TransactionRepository {
  TransactionRepository(this._adb);
  final AppDatabase _adb;

  Future<Database> get _db => _adb.db;

  static (int, int) _range(DateTime month) => (
        DateTime(month.year, month.month).millisecondsSinceEpoch,
        DateTime(month.year, month.month + 1).millisecondsSinceEpoch,
      );

  Future<int> insert(AppTransaction t) async {
    final db = await _db;
    final map = t.toMap()..remove('id');
    return db.insert('transactions', map);
  }

  Future<void> insertAll(List<AppTransaction> list) async {
    final db = await _db;
    final batch = db.batch();
    for (final t in list) {
      batch.insert('transactions', t.toMap()..remove('id'));
    }
    await batch.commit(noResult: true);
  }

  Future<int> update(AppTransaction t) async {
    final db = await _db;
    return db.update('transactions', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAll() async {
    final db = await _db;
    await db.delete('transactions');
  }

  Future<List<AppTransaction>> query({
    DateTime? month,
    int? categoryId,
    String? search,
    int? limit,
  }) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];
    if (month != null) {
      final r = _range(month);
      where.add('date >= ? AND date < ?');
      args..add(r.$1)..add(r.$2);
    }
    if (categoryId != null) {
      where.add('category_id = ?');
      args.add(categoryId);
    }
    if (search != null && search.trim().isNotEmpty) {
      where.add('(merchant LIKE ? OR note LIKE ?)');
      final q = '%${search.trim()}%';
      args..add(q)..add(q);
    }
    final rows = await db.query(
      'transactions',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date DESC, id DESC',
      limit: limit,
    );
    return rows.map(AppTransaction.fromMap).toList();
  }

  Future<double> monthTotal(DateTime month, TxType type) async {
    final db = await _db;
    final r = _range(month);
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount),0) AS t FROM transactions '
      'WHERE type = ? AND date >= ? AND date < ?',
      [type.name, r.$1, r.$2],
    );
    return (rows.first['t'] as num).toDouble();
  }

  /// category_id -> tổng. Giao dịch chưa có danh mục dùng key -1.
  Future<Map<int, double>> categoryTotals(DateTime month, TxType type) async {
    final db = await _db;
    final r = _range(month);
    final rows = await db.rawQuery(
      'SELECT category_id AS c, SUM(amount) AS t FROM transactions '
      'WHERE type = ? AND date >= ? AND date < ? GROUP BY category_id',
      [type.name, r.$1, r.$2],
    );
    return {
      for (final row in rows) ((row['c'] as int?) ?? -1): (row['t'] as num).toDouble(),
    };
  }
}
