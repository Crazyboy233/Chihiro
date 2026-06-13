import 'package:sqlite3/sqlite3.dart';

void main() {
  final db = sqlite3.open('../shark_account.db');
  final rows = db.select('SELECT category_id, category_name, category_type_main FROM category ORDER BY category_type_main, category_name');
  print('所有分类（按类型分组）:');
  for (final r in rows) {
    print('  id=${r['category_id']}, type=${r['category_type_main']}, name=${r['category_name']}');
  }
  db.dispose();
}
