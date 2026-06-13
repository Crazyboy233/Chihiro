/// 解析 shark_account.db 并生成本应用可导入的 JSON。
///
/// 用法（在项目根目录下执行）：
///   阶段一：仅分析 & dump 表结构
///     cd shark_tool && dart run bin/shark_tool.dart analyze ../shark_account.db
///
///   阶段二：转换生成可导入的 JSON
///     cd shark_tool && dart run bin/shark_tool.dart convert ../shark_account.db ../chihiro_backup_from_shark.json
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  if (args.isEmpty || (args[0] != 'analyze' && args[0] != 'convert')) {
    stderr.writeln('用法:');
    stderr.writeln('  dart run shark_tool.dart analyze <db_path>');
    stderr.writeln('  dart run shark_tool.dart convert <db_path> <out_json_path>');
    exit(1);
  }
  final mode = args[0];
  final dbPath = args.length > 1 ? args[1] : 'shark_account.db';

  if (!File(dbPath).existsSync()) {
    stderr.writeln('❌ 找不到数据库文件: ${File(dbPath).absolute.path}');
    exit(2);
  }

  final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);

  // 拿到所有表
  final tableList = db
      .select("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
      .map((r) => r['name'] as String)
      .toList();

  if (mode == 'analyze') {
    doAnalyze(db, tableList);
  } else {
    final outPath = args.length > 2 ? args[2] : 'chihiro_backup_from_shark.json';
    doConvert(db, tableList, outPath);
  }
  db.dispose();
}

// ==========================================================================
// 阶段一：分析
// ==========================================================================
void doAnalyze(Database db, List<String> tables) {
  print('=' * 78);
  print(' shark_account.db  结构 & 数据样例报告  (表数: ${tables.length})');
  print('=' * 78);

  for (final t in tables) {
    final schema = db.select("SELECT sql FROM sqlite_master WHERE name='$t'");
    final createSql = schema.isEmpty ? '' : schema.first[0] as String;
    final resultSet = db.select('SELECT * FROM "$t"');
    final columnNames = resultSet.columnNames;
    final rowCount = resultSet.length;
    print('');
    print('--- 表: $t（共 $rowCount 行）---');
    print(' 建表SQL: $createSql');
    if (rowCount == 0) {
      print(' 数据: 空表');
      continue;
    }
    print(' 字段: ${columnNames.join(', ')}');
    final shown = rowCount > 5 ? 5 : rowCount;
    for (var i = 0; i < shown; i++) {
      print(' [${i + 1}] ${rowToString(columnNames, resultSet[i])}');
    }
    if (rowCount > 5) print(' ... 共 $rowCount 行');
  }
}

String rowToString(List<String> columnNames, Row r) {
  final parts = <String>[];
  for (final c in columnNames) {
    final v = r[c];
    parts.add('$c=${v == null ? 'null' : v.toString().replaceAll('\n', '\\n')}');
  }
  return '{${parts.join(', ')}}';
}

// —— 帮助：把一行转成 "小写字段名 → 值" 的 Map ——
Map<String, dynamic> rowToMap(List<String> columnNames, Row r) {
  final out = <String, dynamic>{};
  for (final c in columnNames) out[c.toLowerCase()] = r[c];
  return out;
}

// ==========================================================================
// 阶段二：转换 → 本应用可导入的 JSON（针对 shark_account.db 专用）
// ==========================================================================
void doConvert(Database db, List<String> tables, String outPath) {
  // shark_account.db 的表名是固定的
  //   category 表 (分类)
  //   account_detail 表 (记账记录)
  const sharkCategoryTable = 'category';
  const sharkTransactionTable = 'account_detail';

  // ========== 1) 解析分类表 ==========
  final categoryRs = db.select('SELECT * FROM "$sharkCategoryTable"');
  final categoryCols = categoryRs.columnNames;

  // 原 category_id → 新 id（用于 account_detail 表的 cid 字段映射）
  final oldCategoryIdToNewId = <String, int>{};
  // 原 category_id → 收支类型：expenses/income
  final oldCategoryIdToType = <String, String>{};

  final categories = <Map<String, dynamic>>[];
  var nextCategoryId = 1;
  final seenCategoryKeys = <String>{}; // name|type 去重用

  for (final r in categoryRs) {
    final cols = rowToMap(categoryCols, r);
    final oldId = (cols['category_id'] ?? cols['cid'] ?? '').toString();
    if (oldId.isEmpty) continue;

    final name = (cols['category_name'] ?? cols['name'] ?? '').toString();
    if (name.isEmpty) continue;

    // 收支类型：category_type_main 字段 — "expenses" 或 "income"
    final rawType = (cols['category_type_main'] ?? cols['type'] ?? 'expenses').toString();
    final type = rawType.toLowerCase().startsWith('income') ? 'income' : 'expense';

    // 去重
    final key = '$name|$type';
    if (seenCategoryKeys.contains(key)) {
      // 重名分类仍保留映射，让明细能指向现有 id
      final existingId = categories.firstWhere((c) =>
          c['name'] == name && c['type'] == type)['id'] as int? ?? nextCategoryId;
      oldCategoryIdToNewId[oldId] = existingId;
      oldCategoryIdToType[oldId] = type;
      continue;
    }
    seenCategoryKeys.add(key);

    // 图标 & 颜色：优先用 icon_name 猜测，没有则回退到按分类名
    final iconName = (cols['icon_name'] ?? '').toString();
    final style = guessCategoryStyleFromIcon(iconName, fallback: guessCategoryStyle(name));

    final sortOrder = cols['category_order'] ?? cols['corder'];
    final sortOrderInt = (sortOrder is num) ? sortOrder.toInt() : nextCategoryId;

    categories.add({
      'id': nextCategoryId,
      'name': name,
      'type': type,
      'icon': style['icon'],
      'color': style['color'],
      'is_default': 0,
      'sort_order': sortOrderInt,
    });
    oldCategoryIdToNewId[oldId] = nextCategoryId;
    oldCategoryIdToType[oldId] = type;
    nextCategoryId++;
  }

  // ========== 2) 解析记账记录表 ==========
  final txRs = db.select('SELECT * FROM "$sharkTransactionTable"');
  final txCols = txRs.columnNames;

  final transactions = <Map<String, dynamic>>[];
  var skippedNoCid = 0;
  var skippedBadAmount = 0;
  var skippedNoDate = 0;
  var autoCreatedCategories = 0;

  for (final r in txRs) {
    final cols = rowToMap(txCols, r);

    // 金额
    final amountRaw = cols['account'] ?? cols['amount'];
    if (amountRaw == null) { skippedBadAmount++; continue; }
    final amount = amountRaw is num
        ? amountRaw.toDouble()
        : double.tryParse(amountRaw.toString()) ?? 0.0;
    if (amount <= 0) { skippedBadAmount++; continue; }

    // 日期：优先用 date_s (秒级时间戳), 其次用 year/month/day 组合
    String? dateStr;
    final date_s = cols['date_s'];
    if (date_s is num && date_s > 0) {
      final dt = DateTime.fromMillisecondsSinceEpoch((date_s.toInt() * 1000));
      dateStr = '${dt.year.toString().padLeft(4, '0')}-'
          '${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')}';
    } else {
      final y = (cols['year'] ?? '').toString();
      final m = (cols['month'] ?? '').toString();
      final d = (cols['day'] ?? '').toString();
      if (y.isNotEmpty && m.isNotEmpty && d.isNotEmpty) {
        dateStr = '${y.padLeft(4, '0')}-${m.padLeft(2, '0')}-${d.padLeft(2, '0')}';
      }
    }
    if (dateStr == null) { skippedNoDate++; continue; }

    // 分类映射：用 cid (category_id) 找原分类表
    final cid = (cols['cid'] ?? '').toString();
    if (cid.isEmpty) { skippedNoCid++; continue; }

    int categoryId;
    String type;
    if (oldCategoryIdToNewId.containsKey(cid)) {
      categoryId = oldCategoryIdToNewId[cid]!;
      type = oldCategoryIdToType[cid] ?? 'expense';
    } else {
      // 找不到对应分类 → 自动创建 "其他" 分类
      const fallbackName = '其他';
      final fallbackKey = '$fallbackName|expense';
      int fallbackId;
      if (seenCategoryKeys.contains(fallbackKey)) {
        fallbackId = categories.firstWhere((c) =>
            c['name'] == fallbackName && c['type'] == 'expense')['id'] as int;
      } else {
        final style = guessCategoryStyle(fallbackName);
        fallbackId = nextCategoryId;
        categories.add({
          'id': fallbackId,
          'name': fallbackName,
          'type': 'expense',
          'icon': style['icon'],
          'color': style['color'],
          'is_default': 0,
          'sort_order': nextCategoryId,
        });
        seenCategoryKeys.add(fallbackKey);
        oldCategoryIdToNewId[cid] = fallbackId;
        oldCategoryIdToType[cid] = 'expense';
        nextCategoryId++;
        autoCreatedCategories++;
      }
      categoryId = fallbackId;
      type = 'expense';
    }

    // 备注
    final remark = (cols['remark'] ?? cols['note'] ?? '').toString();

    // 创建时间：date_s 是秒级时间戳
    String createdAt = dateStr;
    if (date_s is num && date_s > 0) {
      final dt = DateTime.fromMillisecondsSinceEpoch((date_s.toInt() * 1000));
      createdAt = dt.toIso8601String();
    } else {
      createdAt = '$dateStr/T00:00:00'.replaceAll('/T', 'T');
    }
    final updatedAt = createdAt;

    transactions.add({
      'id': transactions.length + 1,
      'type': type,
      'category_id': categoryId,
      'amount': amount,
      'date': dateStr,
      'category_note': '',
      'note': remark,
      'created_at': createdAt,
      'updated_at': updatedAt,
    });
  }

  // ========== 3) 输出 JSON ==========
  final output = {
    'version': 2,
    'exported_at': DateTime.now().toIso8601String(),
    'note': '由 shark_account.db 转换生成。导入模式：追加合并（不会清空当前数据）',
    'source_info': {
      'source': 'shark_account.db',
      'original_category_table': sharkCategoryTable,
      'original_transaction_table': sharkTransactionTable,
      'original_category_count': categoryRs.length,
      'original_transaction_count': txRs.length,
    },
    'tables': {
      'categories': categories,
      'schedule_categories': [],
      'habit_goals': [],
      'transactions': transactions,
      'schedules': [],
      'habit_records': [],
    },
  };

  final outFile = File(outPath);
  outFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(output),
      encoding: utf8);

  print('\n✅ 转换完成:');
  print('  分类: ${categories.length} 条（自动补全 $autoCreatedCategories 条）');
  print('  记账: ${transactions.length} 条');
  print('  跳过: 无分类=$skippedNoCid 条, 金额无效=$skippedBadAmount 条, 日期无效=$skippedNoDate 条');
  print('  输出文件: ${outFile.absolute.path}');
  print('  文件大小: ${(outFile.lengthSync() / 1024).toStringAsFixed(1)} KB');
}

// —— 根据 shark_account 的 icon_name 猜图标 & 颜色 ——
Map<String, String> guessCategoryStyleFromIcon(String iconName, {required Map<String, String> fallback}) {
  if (iconName.isEmpty) return fallback;
  final lower = iconName.toLowerCase();

  // 按关键字匹配（对应 shark_account 的常见 icon_name）
  if (lower.contains('cater') || lower.contains('food') || lower.contains('餐饮') ||
      lower.contains('meal') || lower.contains('lunch') || lower.contains('dinner')) {
    return {'icon': '🍔', 'color': '#EF4444'};
  }
  if (lower.contains('shopping') || lower.contains('shop') || lower.contains('购物')) {
    return {'icon': '🛒', 'color': '#8B5CF6'};
  }
  if (lower.contains('traffic') || lower.contains('bus') || lower.contains('交通') ||
      lower.contains('car') || lower.contains('taxi')) {
    return {'icon': '🚗', 'color': '#F59E0B'};
  }
  if (lower.contains('train') || lower.contains('metro') || lower.contains('subway') ||
      lower.contains('地铁')) {
    return {'icon': '🚇', 'color': '#3B82F6'};
  }
  if (lower.contains('medical') || lower.contains('medical') || lower.contains('医院')) {
    return {'icon': '🏥', 'color': '#10B981'};
  }
  if (lower.contains('entertain') || lower.contains('movie') || lower.contains('娱乐') ||
      lower.contains('game')) {
    return {'icon': '🎮', 'color': '#7C3AED'};
  }
  if (lower.contains('study') || lower.contains('education') || lower.contains('学习')) {
    return {'icon': '📚', 'color': '#EAB308'};
  }
  if (lower.contains('drink') || lower.contains('tea') || lower.contains('coffee') ||
      lower.contains('饮品')) {
    return {'icon': '☕', 'color': '#D97706'};
  }
  if (lower.contains('home') || lower.contains('house') || lower.contains('住房') ||
      lower.contains('rent')) {
    return {'icon': '🏠', 'color': '#D97706'};
  }
  if (lower.contains('daily') || lower.contains('life') || lower.contains('日用') ||
      lower.contains('daily')) {
    return {'icon': '🧴', 'color': '#0891B2'};
  }
  if (lower.contains('salary') || lower.contains('工资') || lower.contains('income') ||
      lower.contains('pay')) {
    return {'icon': '💰', 'color': '#10B981'};
  }
  if (lower.contains('bonus') || lower.contains('红包') || lower.contains('奖励')) {
    return {'icon': '🎁', 'color': '#F59E0B'};
  }
  if (lower.contains('travel') || lower.contains('trip') || lower.contains('旅行')) {
    return {'icon': '✈️', 'color': '#6366F1'};
  }
  if (lower.contains('digital') || lower.contains('数码') || lower.contains('phone')) {
    return {'icon': '💻', 'color': '#14B8A6'};
  }
  if (lower.contains('donate') || lower.contains('donation') || lower.contains('捐赠') ||
      lower.contains('公益')) {
    return {'icon': '❤️', 'color': '#EC4899'};
  }
  if (lower.contains('pet') || lower.contains('宠物')) {
    return {'icon': '🐶', 'color': '#F59E0B'};
  }
  if (lower.contains('snack') || lower.contains('零食') || lower.contains('candy')) {
    return {'icon': '🍫', 'color': '#DC2626'};
  }
  if (lower.contains('fruit') || lower.contains('水果')) {
    return {'icon': '🍎', 'color': '#F97316'};
  }
  if (lower.contains('vegetable') || lower.contains('蔬菜')) {
    return {'icon': '🥬', 'color': '#10B981'};
  }
  if (lower.contains('sport') || lower.contains('健身') || lower.contains('运动') ||
      lower.contains('gym')) {
    return {'icon': '🏋️', 'color': '#059669'};
  }
  if (lower.contains('gift') || lower.contains('礼物') || lower.contains('赠送')) {
    return {'icon': '🎁', 'color': '#F59E0B'};
  }

  // 兜底：用分类名再猜一次
  return fallback;
}

// —— 分类行解析（cols 已是 小写字段名→值）——
Map<String, dynamic>? parseCategoryRow(Map<String, dynamic> cols, {required int id}) {
  final name = (cols['name'] ?? cols['分类'] ?? cols['名称'] ?? cols['category_name'] ?? '').toString();
  if (name.isEmpty || name == 'null') return null;

  final rawType = (cols['type'] ?? cols['类型'] ?? cols['kind'] ?? 'expense').toString();
  final type = (rawType.toLowerCase().contains('income') ||
          rawType.contains('收入') ||
          rawType == 'in' ||
          rawType == '1')
      ? 'income'
      : 'expense';

  // icon / color：有就用，没有就按名字推测
  String icon = (cols['icon'] ?? cols['图标'] ?? '').toString();
  String color = (cols['color'] ?? cols['颜色'] ?? '').toString();
  if (icon.isEmpty || color.isEmpty) {
    final hint = guessCategoryStyle(name);
    icon = icon.isEmpty ? hint['icon']! : icon;
    color = color.isEmpty ? hint['color']! : color;
  }
  if (!color.startsWith('#')) color = '#$color';

  return {
    'id': id,
    'name': name,
    'type': type,
    'icon': icon,
    'color': color,
    'is_default': 0,
    'sort_order': id,
  };
}

// —— 记账记录行解析（cols 已是 小写字段名→值）——
Map<String, dynamic>? parseTransactionRow(
  Map<String, dynamic> cols, {
  required int id,
  required Map<String, int> nameToId,
  required int Function(Map<String, dynamic> cat) onNewCategory,
}) {
  // 金额
  final amountRaw = cols['amount'] ??
      cols['金额'] ??
      cols['money'] ??
      cols['price'] ??
      cols['value'];
  if (amountRaw == null) return null;
  final amount = amountRaw is num
      ? amountRaw.toDouble()
      : double.tryParse(amountRaw.toString()) ?? 0.0;
  if (amount <= 0) return null;

  // 收支类型
  final rawType = (cols['type'] ?? cols['收支'] ?? cols['类型'] ?? 'expense').toString();
  bool income = rawType.toLowerCase().contains('income') ||
      rawType.contains('收入') ||
      rawType == 'in' ||
      rawType == '1';
  // 金额永远取绝对值，避免负数金额
  final absAmount = amount.abs();
  final type = income ? 'income' : 'expense';

  // 日期
  final rawDate = cols['date'] ??
      cols['日期'] ??
      cols['transaction_date'] ??
      cols['created_at'] ??
      cols['create_time'] ??
      cols['time'] ??
      cols['时间'];
  final dateStr = normalizeDate(rawDate);
  if (dateStr == null) return null;

  // 分类名 → 找已有分类 id
  final categoryName = (cols['category_name'] ??
          cols['category'] ??
          cols['分类'] ??
          cols['类别'] ??
          cols['c_name'] ??
          '')
      .toString();

  int categoryId;
  if (nameToId.containsKey(categoryName)) {
    categoryId = nameToId[categoryName]!;
  } else {
    // 找不到分类名时，按分类名新增一个分类
    final hint = guessCategoryStyle(categoryName.isEmpty ? '其他' : categoryName);
    final newCat = {
      'name': categoryName.isEmpty ? '其他' : categoryName,
      'type': type,
      'icon': hint['icon'],
      'color': hint['color'],
      'is_default': 0,
    };
    categoryId = onNewCategory(newCat);
  }

  // 备注
  final note = (cols['note'] ??
          cols['备注'] ??
          cols['remark'] ??
          cols['description'] ??
          cols['desc'] ??
          cols['title'] ??
          '')
      .toString();

  // 创建/更新时间
  final createdAt = normalizeDateTime(cols['created_at'] ?? cols['创建时间']) ??
      '$dateStr/T00:00:00'.replaceAll('/T', 'T');
  final updatedAt = normalizeDateTime(cols['updated_at'] ?? cols['更新时间']) ??
      createdAt;

  return {
    'id': id,
    'type': type,
    'category_id': categoryId,
    'amount': absAmount,
    'date': dateStr,
    'category_note': '',
    'note': note,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}

// —— 日期归一化 ——
String? normalizeDate(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  if (s.isEmpty) return null;
  // 整数时间戳（秒/毫秒）
  if (int.tryParse(s) != null) {
    final n = int.parse(s);
    DateTime dt;
    if (s.length >= 13) {
      dt = DateTime.fromMillisecondsSinceEpoch(n);
    } else if (s.length >= 10) {
      dt = DateTime.fromMillisecondsSinceEpoch(n * 1000);
    } else {
      // 太短，不像时间戳
      return null;
    }
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
  // yyyy-MM-dd / yyyy/MM/dd / yyyy.MM.dd / yyyyMMdd / "2024-05-10 12:34:56"
  final digits = s.replaceAll(RegExp(r'\D'), '');
  if (digits.length >= 8) {
    final y = int.parse(digits.substring(0, 4));
    final m = int.parse(digits.substring(4, 6));
    final d = int.parse(digits.substring(6, 8));
    if (y < 1970 || y > 2200 || m < 1 || m > 12 || d < 1 || d > 31) return null;
    return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
  }
  return null;
}

String? normalizeDateTime(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  if (s.isEmpty) return null;
  if (int.tryParse(s) != null) {
    final n = int.parse(s);
    DateTime dt = s.length >= 13
        ? DateTime.fromMillisecondsSinceEpoch(n)
        : DateTime.fromMillisecondsSinceEpoch(n * 1000);
    return dt.toIso8601String();
  }
  final digits = s.replaceAll(RegExp(r'\D'), '');
  if (digits.length >= 14) {
    // yyyyMMddHHmmss
    final y = int.parse(digits.substring(0, 4));
    final m = int.parse(digits.substring(4, 6));
    final d = int.parse(digits.substring(6, 8));
    final h = int.parse(digits.substring(8, 10));
    final min = int.parse(digits.substring(10, 12));
    final sec = int.parse(digits.substring(12, 14));
    return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}T${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
  if (digits.length >= 8) {
    final y = int.parse(digits.substring(0, 4));
    final m = int.parse(digits.substring(4, 6));
    final d = int.parse(digits.substring(6, 8));
    return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}T00:00:00';
  }
  return null;
}

// —— 按中文分类名猜图标和颜色 ——
Map<String, String> guessCategoryStyle(String name) {
  final n = name;
  if (n.contains('餐饮') || n.contains('吃饭') || n.contains('早餐') || n.contains('午餐') || n.contains('晚餐')) {
    return {'icon': '🍔', 'color': '#EF4444'};
  }
  if (n.contains('交通') || n.contains('打车') || n.contains('地铁') || n.contains('公交') || n.contains('出租')) {
    return {'icon': '🚗', 'color': '#F59E0B'};
  }
  if (n.contains('购物')) {
    return {'icon': '🛒', 'color': '#8B5CF6'};
  }
  if (n.contains('娱乐') || n.contains('电影') || n.contains('游戏')) {
    return {'icon': '🎮', 'color': '#7C3AED'};
  }
  if (n.contains('蔬菜') || n.contains('水果')) {
    return {'icon': '🥬', 'color': '#10B981'};
  }
  if (n.contains('日用') || n.contains('生活') || n.contains('家居')) {
    return {'icon': '🧴', 'color': '#0891B2'};
  }
  if (n.contains('住房') || n.contains('房租') || n.contains('水电') || n.contains('煤气') || n.contains('物业')) {
    return {'icon': '🏠', 'color': '#D97706'};
  }
  if (n.contains('旅行') || n.contains('旅游') || n.contains('机票') || n.contains('酒店')) {
    return {'icon': '✈️', 'color': '#6366F1'};
  }
  if (n.contains('数码') || n.contains('电子') || n.contains('手机') || n.contains('电脑')) {
    return {'icon': '💻', 'color': '#14B8A6'};
  }
  if (n.contains('学习') || n.contains('书籍') || n.contains('书') || n.contains('教育')) {
    return {'icon': '📚', 'color': '#EAB308'};
  }
  if (n.contains('长辈') || n.contains('父母') || n.contains('家人')) {
    return {'icon': '👨‍👩‍👧', 'color': '#64748B'};
  }
  if (n.contains('社交') || n.contains('朋友') || n.contains('送礼')) {
    return {'icon': '👥', 'color': '#4755A9'};
  }
  if (n.contains('工资') || n.contains('薪资') || n.contains('薪水')) {
    return {'icon': '💰', 'color': '#10B981'};
  }
  if (n.contains('奖金') || n.contains('红包')) {
    return {'icon': '🎁', 'color': '#F59E0B'};
  }
  if (n.contains('理财') || n.contains('投资') || n.contains('利息')) {
    return {'icon': '📈', 'color': '#3B82F6'};
  }
  if (n.contains('兼职') || n.contains('外快') || n.contains('副业')) {
    return {'icon': '💼', 'color': '#8B5CF6'};
  }
  return {'icon': '📦', 'color': '#64748B'}; // 兜底：其他
}
