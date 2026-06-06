import 'package:flutter/foundation.dart';
import '../models/habit_goal.dart';
import '../models/habit_record.dart';
import '../services/database_service.dart';

class HabitProvider with ChangeNotifier {
  List<HabitGoal> _goals = [];
  Map<int, List<HabitRecord>> _records = {};
  bool _isLoading = false;

  List<HabitGoal> get goals => _goals;
  bool get isLoading => _isLoading;

  Future<void> loadGoals() async {
    _isLoading = true;
    notifyListeners();

    try {
      _goals = await DatabaseService.instance.getActiveHabitGoals();
    } catch (e) {
      debugPrint('加载打卡目标失败: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadRecords(int goalId, DateTime startDate, DateTime endDate) async {
    try {
      final records = await DatabaseService.instance.getHabitRecords(goalId, startDate, endDate);
      _records[goalId] = records;
      notifyListeners();
    } catch (e) {
      debugPrint('加载打卡记录失败: $e');
    }
  }

  List<HabitRecord> getRecords(int goalId) {
    return _records[goalId] ?? [];
  }

  Future<int> addGoal(HabitGoal goal) async {
    try {
      final id = await DatabaseService.instance.insertHabitGoal(goal);
      goal.id = id;
      _goals.insert(0, goal);
      notifyListeners();
      return id;
    } catch (e) {
      debugPrint('添加打卡目标失败: $e');
      rethrow;
    }
  }

  Future<void> updateGoal(HabitGoal goal) async {
    try {
      await DatabaseService.instance.updateHabitGoal(goal);
      final index = _goals.indexWhere((g) => g.id == goal.id);
      if (index != -1) {
        _goals[index] = goal;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('更新打卡目标失败: $e');
      rethrow;
    }
  }

  Future<void> deleteGoal(int id) async {
    try {
      await DatabaseService.instance.deleteHabitGoal(id);
      _goals.removeWhere((g) => g.id == id);
      _records.remove(id);
      notifyListeners();
    } catch (e) {
      debugPrint('删除打卡目标失败: $e');
      rethrow;
    }
  }

  Future<int> addRecord(HabitRecord record) async {
    try {
      final id = await DatabaseService.instance.insertHabitRecord(record);
      record.id = id;
      if (_records.containsKey(record.goalId)) {
        _records[record.goalId]!.add(record);
      } else {
        _records[record.goalId] = [record];
      }
      notifyListeners();
      return id;
    } catch (e) {
      debugPrint('添加打卡记录失败: $e');
      rethrow;
    }
  }

  bool isCompleted(int goalId, DateTime date) {
    final records = getRecords(goalId);
    final dateStr = date.toIso8601String().split('T')[0];
    return records.any((r) => r.date == dateStr && r.isCompleted == 1);
  }
}
