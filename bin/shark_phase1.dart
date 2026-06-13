/// 阶段一：dump shark_account.db 的结构和数据样例
/// 运行：在项目根目录执行  dart run bin/shark_phase1.dart
import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const dbPath = 'shark_account.db';
const outReport = 'shark_account_report.txt';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final db = await openDatabase(dbPath, readOnly: true);

  // —— 1) 表列表
  final tables = (await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
  ))
      .map((r) => r['name'] as String)
      .toList();

  final buf = StringBuffer();
  buf.writeln('=' * 78);
  buf.writeln(' shark_account.db  结构 & 数据样例报告');
  buf.writeln('=' * 78);
  buf.writeln('\n共发现 ${tables.length} 张表：\n');

  // —— 2) 每张表：建表 SQL + 全量数据
  final tableData = <String, List<Map<String, dynamic>>>{};
  for (final t in tables) {
    final schema =
        await db.rawQuery("SELECT sql FROM sqlite_master WHERE name='$t'");
    final createSql = (schema.first['sql'] as String?) ?? '';
    final rows = await db.rawQuery('SELECT * FROM "$t"');
    tableData[t] = rows;

    buf.writeln('--- 表: $t（共 ${rows.length} 行）---');
    buf.writeln(' 建表SQL: $createSql');
    if (rows.isEmpty) {
      buf.writeln(' 数据: 空表');
    } else {
      buf.writeln(' 字段: ${rows.first.keys.join(', ')}');
      // 最多打印 5 条样例
      for (var i = 0; i < rows.length && i < 5; i++) {
        buf.writeln('  [${i + 1}] ${_pretty(rows[i])}');
      }
      if (rows.length > 5) buf.writeln('  ... 共 ${rows.length} 行');
    }
    buf.writeln('');
  }

  await db.close();

  // —— 3) 汇总写入报告文件 & 控制台输出
  await File(outReport).writeAsString(buf.toString(), encoding: utf8);
  stdout.write(buf.toString());

  // —— 4) 把全量数据也保存一份 JSON（方便手工核查）
  final allTablesJson = <String, dynamic>{};
  for (final t in tables) {
    allTablesJson[t] = tableData[t]!.map((e) => _toStringKeys(e)).toList();
  }
  await File('shark_account_raw.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert(allTablesJson),
    encoding: utf8,
  );

  print('\n✅ 报告已写入: ${File(outReport).absolute.path}');
  print('✅ 原始数据已写入: ${File('shark_account_raw.json').absolute.path}');
}

String _pretty(Map<String, dynamic> m) {
  final parts = <String>[];
  for (final e in m.entries) {
    final v = e.value;
    final str = v == null ? 'null' : v.toString();
    parts.add('${e.key}=${str.length > 80 ? '${str.substring(0, 80)}...' : str}');
  }
  return '{${parts.join(', ')}}';
}

// sqflite 返回的 key 是 String，但 value 可能是 int/double/String/Null
// 为了可被 jsonEncode 序列化，把所有 value 都 toString/保留原值。
Map<String, dynamic> _toStringKeys(Map<String, dynamic> m) {
  final out = <String, dynamic>{};
  for (final e in m.entries) {
    final v = e.value;
    if (v is num || v is String || v == null) {
      out[e.key] = v;
    } else if (v is List<int>) {
      // BLOB
      out[e.key] = '<BLOB ${v.length} bytes>';
    } else {
      out[e.key] = v.toString();
    }
  }
  return out;
}
