import 'package:receipt_tracker/data/db/app_database.dart';
import 'package:receipt_tracker/data/models/category.dart';

class CategoryRepository {
  CategoryRepository(this._adb);
  final AppDatabase _adb;

  Future<List<Category>> all() async {
    final db = await _adb.db;
    final rows = await db.query('categories', orderBy: 'id ASC');
    return rows.map(Category.fromMap).toList();
  }
}
