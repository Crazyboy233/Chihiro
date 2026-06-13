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

  static const List<Map<String, Object>> defaultCategories = [
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
    {'name': '其他', 'type': 'expense', 'icon': '📦', 'color': '#64748B', 'is_default': 1, 'sort_order': 20},
    {'name': '工资', 'type': 'income', 'icon': '💰', 'color': '#10B981', 'is_default': 1, 'sort_order': 1},
    {'name': '奖金', 'type': 'income', 'icon': '🎁', 'color': '#F59E0B', 'is_default': 1, 'sort_order': 2},
    {'name': '理财', 'type': 'income', 'icon': '📈', 'color': '#3B82F6', 'is_default': 1, 'sort_order': 3},
    {'name': '兼职', 'type': 'income', 'icon': '💼', 'color': '#8B5CF6', 'is_default': 1, 'sort_order': 4},
    {'name': '补助', 'type': 'income', 'icon': '🎗️', 'color': '#06B6D4', 'is_default': 1, 'sort_order': 5},
    {'name': '补偿', 'type': 'income', 'icon': '💵', 'color': '#84CC16', 'is_default': 1, 'sort_order': 6},
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

  Future<void> ensureDefaultCategories(Database db) async {
    final expenseCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM categories WHERE type = ?', ['expense']),
        ) ??
        0;
    final incomeCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM categories WHERE type = ?', ['income']),
        ) ??
        0;

    // 清理历史错误数据：旧版本曾把「补助/补偿」作为支出分类，现改为收入分类
    await db.delete(
      'categories',
      where: 'name IN (?, ?) AND type = ?',
      whereArgs: ['补助', '补偿', 'expense'],
    );

    // 完全空表 → 批量插入
    if (expenseCount == 0) {
      await insertDefaultCategories(db, type: 'expense');
    }
    if (incomeCount == 0) {
      await insertDefaultCategories(db, type: 'income');
    }

    // 已有数据 → 逐个检查缺失的分类并插入（用于后续新增默认分类时的兼容）
    if (expenseCount > 0 || incomeCount > 0) {
      for (final category in defaultCategories) {
        final name = category['name'] as String;
        final type = category['type'] as String;
        final existing = Sqflite.firstIntValue(
              await db.rawQuery(
                'SELECT COUNT(*) FROM categories WHERE name = ? AND type = ?',
                [name, type],
              ),
            ) ??
            0;
        if (existing == 0) {
          await db.insert('categories', category);
        }
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
