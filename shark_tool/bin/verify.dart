import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final path = args.isNotEmpty ? args[0] : '../chihiro_backup_from_shark.json';
  final file = File(path);
  if (!file.existsSync()) {
    print('❌ 找不到文件: ${file.absolute.path}');
    exit(1);
  }
  final data = jsonDecode(file.readAsStringSync(encoding: utf8)) as Map<String, dynamic>;
  final tables = data['tables'] as Map<String, dynamic>;
  final cats = (tables['categories'] as List).cast<Map<String, dynamic>>();
  final txs = (tables['transactions'] as List).cast<Map<String, dynamic>>();

  print('JSON 版本: ${data['version']}');
  print('导出时间: ${data['exported_at']}');
  print('分类总数: ${cats.length}');
  print('记账总数: ${txs.length}');

  // 按日期排序后取几条
  txs.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
  print('\n=== 最近 5 条记账记录 ===');
  for (var i = 0; i < 5 && i < txs.length; i++) {
    final t = txs[i];
    final cat = cats.firstWhere((c) => c['id'] == t['category_id'], orElse: () => {'name': '未知'});
    print('  [${i + 1}] ${t['date']}  ¥${t['amount']}  [${t['type']}]  ${cat['name']}  备注: "${t['note']}"');
  }

  // 统计
  final incomeTxs = txs.where((t) => t['type'] == 'income');
  final expenseTxs = txs.where((t) => t['type'] == 'expense');
  final totalIncome = incomeTxs.fold<double>(0, (sum, t) => sum + (t['amount'] as num).toDouble());
  final totalExpense = expenseTxs.fold<double>(0, (sum, t) => sum + (t['amount'] as num).toDouble());
  print('\n=== 汇总 ===');
  print('  收入: ${incomeTxs.length} 条, 合计 ¥${totalIncome.toStringAsFixed(2)}');
  print('  支出: ${expenseTxs.length} 条, 合计 ¥${totalExpense.toStringAsFixed(2)}');

  // 按分类统计 Top 10（支出）
  print('\n=== 支出分类 Top 10 ===');
  final byCategory = <String, double>{};
  for (final t in expenseTxs) {
    final cat = cats.firstWhere((c) => c['id'] == t['category_id'], orElse: () => {'name': '未知'});
    final name = cat['name'] as String;
    byCategory[name] = (byCategory[name] ?? 0) + (t['amount'] as num).toDouble();
  }
  final sorted = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  for (var i = 0; i < sorted.length && i < 10; i++) {
    print('  ${i + 1}. ${sorted[i].key}: ¥${sorted[i].value.toStringAsFixed(2)}');
  }

  print('\n✅ 验证：JSON 格式合法，可导入');
}
