import 'package:flutter/foundation.dart' hide Category;
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/schedule.dart';
import '../models/schedule_category.dart';
import '../models/habit_goal.dart';
import '../models/habit_record.dart';
import '../utils/db_helper.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  DatabaseService._init();

  Future<int> insertTransaction(Transaction transaction) async {
    final db = await DBHelper.instance.database;
    return await db.insert('transactions', transaction.toMap());
  }

  Future<int> updateTransaction(Transaction transaction) async {
    final db = await DBHelper.instance.database;
    return await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await DBHelper.instance.database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Transaction>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
    String? searchNote,
  }) async {
    final db = await DBHelper.instance.database;
    String query = 'SELECT * FROM transactions';
    List<String> conditions = [];
    List<dynamic> args = [];

    if (startDate != null && endDate != null) {
      conditions.add('date BETWEEN ? AND ?');
      args.add(startDate.toIso8601String().split('T')[0]);
      args.add(endDate.toIso8601String().split('T')[0]);
    }

    if (categoryId != null) {
      conditions.add('category_id = ?');
      args.add(categoryId);
    }

    if (searchNote != null && searchNote.isNotEmpty) {
      conditions.add('(category_note LIKE ? OR note LIKE ?)');
      args.add('%$searchNote%');
      args.add('%$searchNote%');
    }

    if (conditions.isNotEmpty) {
      query += ' WHERE ' + conditions.join(' AND ');
    }

    query += ' ORDER BY date DESC, created_at DESC';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);

    return List.generate(maps.length, (i) => Transaction.fromMap(maps[i]));
  }

  Future<Map<String, double>> getSummaryByDateRange(DateTime startDate, DateTime endDate) async {
    final db = await DBHelper.instance.database;
    final startStr = startDate.toIso8601String().split('T')[0];
    final endStr = endDate.toIso8601String().split('T')[0];

    final incomeResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total 
      FROM transactions 
      WHERE type = ? AND date BETWEEN ? AND ?
    ''', ['income', startStr, endStr]);

    final expenseResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total 
      FROM transactions 
      WHERE type = ? AND date BETWEEN ? AND ?
    ''', ['expense', startStr, endStr]);

    final income = (incomeResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final expense = (expenseResult.first['total'] as num?)?.toDouble() ?? 0.0;

    return {
      'income': income,
      'expense': expense,
      'balance': income - expense,
    };
  }

  Future<Map<String, double>> getCategorySummary(DateTime startDate, DateTime endDate, String type) async {
    final db = await DBHelper.instance.database;
    final startStr = startDate.toIso8601String().split('T')[0];
    final endStr = endDate.toIso8601String().split('T')[0];

    final result = await db.rawQuery('''
      SELECT c.name, SUM(t.amount) as total
      FROM transactions t
      JOIN categories c ON t.category_id = c.id
      WHERE t.type = ? AND t.date BETWEEN ? AND ?
      GROUP BY c.id
      ORDER BY total DESC
    ''', [type, startStr, endStr]);

    Map<String, double> summary = {};
    for (var row in result) {
      summary[row['name'] as String] = (row['total'] as num).toDouble();
    }

    return summary;
  }

  Future<int> insertCategory(Category category) async {
    final db = await DBHelper.instance.database;
    return await db.insert('categories', category.toMap());
  }

  Future<int> updateCategory(Category category) async {
    final db = await DBHelper.instance.database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await DBHelper.instance.database;
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Category>> getCategories(String type) async {
    final db = await DBHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'sort_order ASC, name ASC',
    );
    debugPrint('Querying categories for type: $type, found ${maps.length}');
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }

  Future<List<Category>> getAllCategories() async {
    final db = await DBHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      orderBy: 'type ASC, sort_order ASC',
    );
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }

  Future<void> initializeDefaultCategories() async {
    final db = await DBHelper.instance.database;
    final existingCategories = await db.query('categories');
    debugPrint('Existing categories count: ${existingCategories.length}');
    
    if (existingCategories.isEmpty) {
      debugPrint('No existing categories, inserting defaults...');
      
      final defaultCategories = [
        {'name': '餐饮', 'type': 'expense', 'icon': '🍔', 'color': '#EF4444', 'is_default': 1, 'sort_order': 1},
        {'name': '交通', 'type': 'expense', 'icon': '🚗', 'color': '#F59E0B', 'is_default': 1, 'sort_order': 2},
        {'name': '购物', 'type': 'expense', 'icon': '🛒', 'color': '#8B5CF6', 'is_default': 1, 'sort_order': 3},
        {'name': '地铁', 'type': 'expense', 'icon': '🚇', 'color': '#3B82F6', 'is_default': 1, 'sort_order': 4},
        {'name': '蔬菜', 'type': 'expense', 'icon': '🥬', 'color': '#10B981', 'is_default': 1, 'sort_order': 5},
        {'name': '水果', 'type': 'expense', 'icon': '🍎', 'color': '#F97316', 'is_default': 1, 'sort_order': 6},
        {'name': '零食', 'type': 'expense', 'icon': '🍫', 'color': '#DC2626', 'is_default': 1, 'sort_order': 7},
        {'name': '运动', 'type': 'expense', 'icon': '🏃', 'color': '#059669', 'is_default': 1, 'sort_order': 8},
        {'name': '娱乐', 'type': 'expense', 'icon': '🎮', 'color': '#7C3AED', 'is_default': 1, 'sort_order': 9},
        {'name': '通讯', 'type': 'expense', 'icon': '📱', 'color': '#0284C7', 'is_default': 1, 'sort_order': 10},
        {'name': '住房', 'type': 'expense', 'icon': '🏠', 'color': '#D97706', 'is_default': 1, 'sort_order': 11},
        {'name': '游戏', 'type': 'expense', 'icon': '🎲', 'color': '#DB2777', 'is_default': 1, 'sort_order': 12},
        {'name': '长辈', 'type': 'expense', 'icon': '👴', 'color': '#64748B', 'is_default': 1, 'sort_order': 13},
        {'name': '社交', 'type': 'expense', 'icon': '👥', 'color': '#475569', 'is_default': 1, 'sort_order': 14},
        {'name': '日用', 'type': 'expense', 'icon': '🧴', 'color': '#0891B2', 'is_default': 1, 'sort_order': 15},
        {'name': '旅行', 'type': 'expense', 'icon': '✈️', 'color': '#6366F1', 'is_default': 1, 'sort_order': 16},
        {'name': '数码', 'type': 'expense', 'icon': '📱', 'color': '#14B8A6', 'is_default': 1, 'sort_order': 17},
        {'name': '学习', 'type': 'expense', 'icon': '📚', 'color': '#EAB308', 'is_default': 1, 'sort_order': 18},
        {'name': 'AI', 'type': 'expense', 'icon': '🤖', 'color': '#EC4899', 'is_default': 1, 'sort_order': 19},
        {'name': '工资', 'type': 'income', 'icon': '💰', 'color': '#10B981', 'is_default': 1, 'sort_order': 1},
        {'name': '奖金', 'type': 'income', 'icon': '🎁', 'color': '#F59E0B', 'is_default': 1, 'sort_order': 2},
        {'name': '理财', 'type': 'income', 'icon': '📈', 'color': '#3B82F6', 'is_default': 1, 'sort_order': 3},
        {'name': '兼职', 'type': 'income', 'icon': '💼', 'color': '#8B5CF6', 'is_default': 1, 'sort_order': 4},
        {'name': '其他', 'type': 'income', 'icon': '📦', 'color': '#64748B', 'is_default': 1, 'sort_order': 5},
      ];
      
      for (var category in defaultCategories) {
        await db.insert('categories', category);
      }
      
      final afterInsert = await db.query('categories');
      debugPrint('After insertion, categories count: ${afterInsert.length}');
    }
  }

  Future<int> insertSchedule(Schedule schedule) async {
    final db = await DBHelper.instance.database;
    return await db.insert('schedules', schedule.toMap());
  }

  Future<int> updateSchedule(Schedule schedule) async {
    final db = await DBHelper.instance.database;
    return await db.update(
      'schedules',
      schedule.toMap(),
      where: 'id = ?',
      whereArgs: [schedule.id],
    );
  }

  Future<int> deleteSchedule(int id) async {
    final db = await DBHelper.instance.database;
    return await db.delete(
      'schedules',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Schedule>> getSchedulesByDateRange(DateTime startDate, DateTime endDate) async {
    final db = await DBHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'schedules',
      where: 'start_time BETWEEN ? AND ?',
      whereArgs: [
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
      orderBy: 'start_time ASC',
    );
    return List.generate(maps.length, (i) => Schedule.fromMap(maps[i]));
  }

  Future<int> insertHabitGoal(HabitGoal goal) async {
    final db = await DBHelper.instance.database;
    return await db.insert('habit_goals', goal.toMap());
  }

  Future<int> updateHabitGoal(HabitGoal goal) async {
    final db = await DBHelper.instance.database;
    return await db.update(
      'habit_goals',
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  Future<int> deleteHabitGoal(int id) async {
    final db = await DBHelper.instance.database;
    return await db.delete(
      'habit_goals',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<HabitGoal>> getActiveHabitGoals() async {
    final db = await DBHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'habit_goals',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => HabitGoal.fromMap(maps[i]));
  }

  Future<int> insertHabitRecord(HabitRecord record) async {
    final db = await DBHelper.instance.database;
    return await db.insert('habit_records', record.toMap());
  }

  Future<List<HabitRecord>> getHabitRecords(int goalId, DateTime startDate, DateTime endDate) async {
    final db = await DBHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'habit_records',
      where: 'goal_id = ? AND date BETWEEN ? AND ?',
      whereArgs: [
        goalId,
        startDate.toIso8601String().split('T')[0],
        endDate.toIso8601String().split('T')[0],
      ],
      orderBy: 'date ASC',
    );
    return List.generate(maps.length, (i) => HabitRecord.fromMap(maps[i]));
  }
}
