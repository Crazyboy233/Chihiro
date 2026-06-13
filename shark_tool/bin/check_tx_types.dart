import 'package:sqlite3/sqlite3.dart';

void main() {
  final db = sqlite3.open('../shark_account.db');
  final rows = db.select('''
    SELECT c.category_id, c.category_name, c.category_type_main, COUNT(t.record_id) as count, COALESCE(SUM(t.account), 0) as total
    FROM category c
    LEFT JOIN account_detail t ON c.category_id = t.cid
    GROUP BY c.category_id, c.category_name, c.category_type_main
    ORDER BY c.category_type_main, count DESC
  ''');
  print('按分类统计记账记录:');
  print('');
  for (final r in rows) {
    print('  type=${r['category_type_main'].toString().padRight(8)}  id=${r['category_id'].toString().padRight(8)}  name=${r['category_name'].toString().padRight(8)}  count=${r['count'].toString().padLeft(5)}  total=¥${r['total']}');
  }
  db.dispose();
}
