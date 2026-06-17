import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;
  static bool _isFfiInitialized = false;

  DBHelper._init();

  // 支出分类（按 sort_order 升序排列，新增分类请追加在「其他」之前）
  static const List<Map<String, Object>> _defaultExpenseCategories = [
    {'name': '餐饮', 'type': 'expense', 'icon': '🍜', 'color': '#EF4444', 'is_default': 1, 'sort_order': 1},
    {'name': '交通', 'type': 'expense', 'icon': '🚌', 'color': '#F59E0B', 'is_default': 1, 'sort_order': 2},
    {'name': '购物', 'type': 'expense', 'icon': '🛍️', 'color': '#8B5CF6', 'is_default': 1, 'sort_order': 3},
    {'name': '地铁', 'type': 'expense', 'icon': '🚇', 'color': '#3B82F6', 'is_default': 1, 'sort_order': 4},
    {'name': '蔬菜', 'type': 'expense', 'icon': '🥬', 'color': '#10B981', 'is_default': 1, 'sort_order': 5},
    {'name': '水果', 'type': 'expense', 'icon': '🍎', 'color': '#F97316', 'is_default': 1, 'sort_order': 6},
    {'name': '零食', 'type': 'expense', 'icon': '🍿', 'color': '#DC2626', 'is_default': 1, 'sort_order': 7},
    {'name': '运动', 'type': 'expense', 'icon': '🏃', 'color': '#059669', 'is_default': 1, 'sort_order': 8},
    {'name': '娱乐', 'type': 'expense', 'icon': '🎬', 'color': '#7C3AED', 'is_default': 1, 'sort_order': 9},
    {'name': '通讯', 'type': 'expense', 'icon': '📱', 'color': '#0284C7', 'is_default': 1, 'sort_order': 10},
    {'name': '住房', 'type': 'expense', 'icon': '🏠', 'color': '#D97706', 'is_default': 1, 'sort_order': 11},
    {'name': '游戏', 'type': 'expense', 'icon': '🎮', 'color': '#DB2777', 'is_default': 1, 'sort_order': 12},
    {'name': '长辈', 'type': 'expense', 'icon': '👪', 'color': '#64748B', 'is_default': 1, 'sort_order': 13},
    {'name': '社交', 'type': 'expense', 'icon': '👥', 'color': '#475569', 'is_default': 1, 'sort_order': 14},
    {'name': '日用', 'type': 'expense', 'icon': '🧻', 'color': '#0891B2', 'is_default': 1, 'sort_order': 15},
    {'name': '旅行', 'type': 'expense', 'icon': '✈️', 'color': '#6366F1', 'is_default': 1, 'sort_order': 16},
    {'name': '数码', 'type': 'expense', 'icon': '💻', 'color': '#14B8A6', 'is_default': 1, 'sort_order': 17},
    {'name': '学习', 'type': 'expense', 'icon': '📚', 'color': '#EAB308', 'is_default': 1, 'sort_order': 18},
    {'name': 'AI', 'type': 'expense', 'icon': '🤖', 'color': '#EC4899', 'is_default': 1, 'sort_order': 19},
    {'name': '孩子', 'type': 'expense', 'icon': '🧸', 'color': '#FFA726', 'is_default': 1, 'sort_order': 22},
    {'name': '研究', 'type': 'expense', 'icon': '🔬', 'color': '#795548', 'is_default': 1, 'sort_order': 23},
    {'name': '礼金', 'type': 'expense', 'icon': '🧧', 'color': '#F06292', 'is_default': 1, 'sort_order': 24},
    {'name': '办公', 'type': 'expense', 'icon': '🗂️', 'color': '#607D8B', 'is_default': 1, 'sort_order': 25},
    {'name': '维修', 'type': 'expense', 'icon': '🔧', 'color': '#5D4037', 'is_default': 1, 'sort_order': 26},
    {'name': '亲友', 'type': 'expense', 'icon': '🧑‍🤝‍🧑', 'color': '#388E3C', 'is_default': 1, 'sort_order': 27},
    {'name': '酒店', 'type': 'expense', 'icon': '🏨', 'color': '#8B4513', 'is_default': 1, 'sort_order': 28},
    {'name': '出去浪', 'type': 'expense', 'icon': '🌊', 'color': '#0288D1', 'is_default': 1, 'sort_order': 29},
    {'name': '其他', 'type': 'expense', 'icon': '📦', 'color': '#64748B', 'is_default': 1, 'sort_order': 999},
  ];

  // 收入分类（按 sort_order 升序排列，新增分类请追加在「其他」之前）
  static const List<Map<String, Object>> _defaultIncomeCategories = [
    {'name': '工资', 'type': 'income', 'icon': '💰', 'color': '#10B981', 'is_default': 1, 'sort_order': 1},
    {'name': '奖金', 'type': 'income', 'icon': '🎁', 'color': '#F59E0B', 'is_default': 1, 'sort_order': 2},
    {'name': '理财', 'type': 'income', 'icon': '📈', 'color': '#3B82F6', 'is_default': 1, 'sort_order': 3},
    {'name': '兼职', 'type': 'income', 'icon': '💼', 'color': '#8B5CF6', 'is_default': 1, 'sort_order': 4},
    {'name': '补助', 'type': 'income', 'icon': '🎗️', 'color': '#06B6D4', 'is_default': 1, 'sort_order': 5},
    {'name': '补偿', 'type': 'income', 'icon': '💵', 'color': '#84CC16', 'is_default': 1, 'sort_order': 6},
    {'name': '其他', 'type': 'income', 'icon': '📥', 'color': '#64748B', 'is_default': 1, 'sort_order': 999},
  ];

  // 全量默认分类（支出 + 收入合并），供数据库初始化和外部使用
  static const List<Map<String, Object>> defaultCategories = [
    ..._defaultExpenseCategories,
    ..._defaultIncomeCategories,
  ];

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('qianxun.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    // 只初始化一次 FFI
    if (!_isFfiInitialized && 
        (defaultTargetPlatform == TargetPlatform.windows || 
        defaultTargetPlatform == TargetPlatform.linux || 
        defaultTargetPlatform == TargetPlatform.macOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _isFfiInitialized = true;
    }

    return openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onOpen: _onOpenDB,
    );
  }

  Future<void> _onOpenDB(Database db) async {
    // 确保 habit_goals 表有 custom_interval_days 列（兜底处理：如果 onUpgrade 未执行或被缓存的旧连接掩盖）
    try {
      final columns = await db.rawQuery("PRAGMA table_info(habit_goals)");
      final hasColumn = columns.any((c) => c['name'].toString() == 'custom_interval_days');
      if (!hasColumn) {
        await db.execute('ALTER TABLE habit_goals ADD COLUMN custom_interval_days INTEGER');
      }
    } catch (_) {
      // 表不存在或列已存在，忽略
    }
    await ensureDefaultCategories(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE schedules ADD COLUMN color TEXT');
      } catch (e) {
        // 列已存在，忽略错误
      }
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE habit_goals ADD COLUMN custom_interval_days INTEGER');
      } catch (e) {
        // 列已存在，忽略错误
      }
    }
  }

  Future<void> _createDB(Database db, int version) async {

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon TEXT NOT NULL,
        color TEXT NOT NULL,
        is_default INTEGER DEFAULT 0,
        sort_order INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        category_note TEXT,
        note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE schedule_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color TEXT NOT NULL,
        icon TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        start_time TEXT NOT NULL,
        end_time TEXT,
        reminder_time TEXT,
        category_id INTEGER,
        is_all_day INTEGER DEFAULT 0,
        calendar_event_id TEXT,
        color TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES schedule_categories (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE habit_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        icon TEXT NOT NULL,
        color TEXT NOT NULL,
        frequency TEXT NOT NULL,
        target_days TEXT,
        custom_interval_days INTEGER,
        start_date TEXT NOT NULL,
        end_date TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE habit_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        is_completed INTEGER DEFAULT 0,
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (goal_id) REFERENCES habit_goals (id)
      )
    ''');

    await insertDefaultCategories(db);
  }

  // 确保 categories 表与当前应用的 defaultCategories 保持一致：
  // 1) 去重  2) 清理非白名单分类（并把其引用的交易迁到「其他」） 3) 缺的补、有的同步字段
  Future<void> ensureDefaultCategories(Database db) async {
    // ---------- 1) 清理历史错误数据 ----------
    // 旧版本曾把「补助/补偿」作为支出分类，现已改为收入分类
    await db.delete(
      'categories',
      where: 'name IN (?, ?) AND type = ?',
      whereArgs: ['补助', '补偿', 'expense'],
    );

    // ---------- 2) 去重：同 name+type 保留 id 最小那条 ----------
    final duplicateCheck = await db.rawQuery('''
      SELECT name, type, MIN(id) AS keep_id
      FROM categories
      GROUP BY name, type
      HAVING COUNT(*) > 1
    ''');
    for (final row in duplicateCheck) {
      await db.delete(
        'categories',
        where: 'name = ? AND type = ? AND id != ?',
        whereArgs: [row['name'] as String, row['type'] as String, row['keep_id'] as int],
      );
    }

    // ---------- 3) 白名单集合：当前应用允许的所有 name+type ----------
    final allowedKeys = <String>{
      for (final c in defaultCategories) '${c['name']}__${c['type']}',
    };

    // ---------- 4) 先确保「其他」分类存在（供后续非法分类的交易重定向用） ----------
    for (final type in const ['expense', 'income']) {
      const name = '其他';
      final existing = await db.query(
        'categories',
        where: 'name = ? AND type = ?',
        whereArgs: [name, type],
        limit: 1,
      );
      if (existing.isEmpty) {
        final defaultList =
            type == 'expense' ? _defaultExpenseCategories : _defaultIncomeCategories;
        final fallback = defaultList.firstWhere((c) => c['name'] == name,
            orElse: () => defaultList.last);
        await db.insert('categories', fallback);
      }
    }

    // ---------- 5) 查询「其他」分类的 id（按 type） ----------
    final fallbackRows = await db.query(
      'categories',
      where: 'name = ? AND (type = ? OR type = ?)',
      whereArgs: ['其他', 'expense', 'income'],
    );
    final fallbackByType = <String, int>{};
    for (final r in fallbackRows) {
      fallbackByType[r['type'] as String] = r['id'] as int;
    }

    // ---------- 6) 清理非白名单分类 ----------
    // 先把引用了这些分类的交易迁到「其他」，再删除分类本身
    final existingCategories = await db.rawQuery('SELECT id, name, type FROM categories');
    final toDeleteIds = <int>[];
    final redirects = <int, int>{}; // 旧 category_id → 其他分类 id

    for (final row in existingCategories) {
      final key = '${row['name']}__${row['type']}';
      if (allowedKeys.contains(key)) continue;

      final oldId = row['id'] as int;
      final type = row['type'] as String;
      final fallbackId = fallbackByType[type == 'income' ? 'income' : 'expense'];
      if (fallbackId != null && fallbackId != oldId) {
        redirects[oldId] = fallbackId;
      }
      toDeleteIds.add(oldId);
    }

    // 6a) 重定向交易记录
    for (final entry in redirects.entries) {
      await db.update(
        'transactions',
        {'category_id': entry.value},
        where: 'category_id = ?',
        whereArgs: [entry.key],
      );
    }

    // 6b) 删除非法分类
    if (toDeleteIds.isNotEmpty) {
      final placeholders = List.filled(toDeleteIds.length, '?').join(',');
      await db.delete(
        'categories',
        where: 'id IN ($placeholders)',
        whereArgs: toDeleteIds,
      );
    }

    // ---------- 7) 确保白名单分类全部存在，且 icon/color/sort_order 与当前应用同步 ----------
    // 用 name+type 做唯一键：缺的就 insert，已有的就 update 字段
    for (final category in defaultCategories) {
      final name = category['name'] as String;
      final type = category['type'] as String;
      final rows = await db.query(
        'categories',
        where: 'name = ? AND type = ?',
        whereArgs: [name, type],
        limit: 1,
      );
      if (rows.isEmpty) {
        await db.insert('categories', category);
      } else {
        await db.update(
          'categories',
          {
            'icon': category['icon'],
            'color': category['color'],
            'sort_order': category['sort_order'],
            'is_default': 1,
          },
          where: 'id = ?',
          whereArgs: [rows.first['id']],
        );
      }
    }
  }

  Future<void> insertDefaultCategories(Database db, {String? type}) async {
    final categories = type == null
        ? defaultCategories
        : defaultCategories.where((category) => category['type'] == type);

    for (final category in categories) {
      await db.insert('categories', category);
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }
}
