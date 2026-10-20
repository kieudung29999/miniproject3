import 'package:receipt_tracker/data/db/app_database.dart';
import 'package:receipt_tracker/data/models/ai_insight.dart';

class InsightRepository {
  InsightRepository(this._adb);
  final AppDatabase _adb;

  Future<AiInsight?> latest(String month) async {
    final db = await _adb.db;
    final rows = await db.query(
      'ai_insights',
      where: 'month = ?',
      whereArgs: [month],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : AiInsight.fromMap(rows.first);
  }

  Future<void> save(AiInsight i) async {
    final db = await _adb.db;
    await db.insert('ai_insights', i.toMap()..remove('id'));
  }

  Future<void> deleteAll() async {
    final db = await _adb.db;
    await db.delete('ai_insights');
  }
}
