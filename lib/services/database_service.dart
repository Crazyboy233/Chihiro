import '../models/category.dart';
import '../models/transaction.dart';
import '../models/schedule.dart';
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
      query += ' WHERE ${conditions.join(' AND ')}';
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

  /// ⚠️ 已废弃：默认分类的初始化统一由 DBHelper 负责
  /// （在数据库打开时自动调用 ensureDefaultCategories）
  /// 保留此方法仅为了兼容历史代码，内部直接转发到 DBHelper
  Future<void> initializeDefaultCategories() async {
    final db = await DBHelper.instance.database;
    await DBHelper.instance.ensureDefaultCategories(db);
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
    final endOfRange = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    final List<Map<String, dynamic>> maps = await db.query(
      'schedules',
      where: 'start_time <= ? AND (end_time IS NULL OR end_time >= ?)',
      whereArgs: [
        endOfRange.toIso8601String(),
        startDate.toIso8601String(),
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

  Future<int> updateHabitRecord(HabitRecord record) async {
    final db = await DBHelper.instance.database;
    return await db.update(
      'habit_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }
}
