import 'package:flutter/foundation.dart';
import '../models/habit_goal.dart';
import '../models/habit_record.dart';
import '../services/database_service.dart';
import '../utils/holiday_service.dart';

class HabitProvider with ChangeNotifier {
  List<HabitGoal> _goals = [];
  final Map<int, List<HabitRecord>> _records = {};
  final Map<DateTime, Set<int>> _completedGoalIds = {};
  bool _isLoading = false;

  List<HabitGoal> get goals => _goals;
  bool get isLoading => _isLoading;

  Future<void> loadGoals() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 确保节假日服务已准备好（内置数据 + 本地缓存）
      await HolidayService().ensureInitialized();
      // 异步尝试在线刷新（不阻塞，本次会话内最多尝试一次）
      HolidayService().tryRefreshOnline();

      _goals = await DatabaseService.instance.getActiveHabitGoals();
      
      // 加载当前月份的所有记录
      final now = DateTime.now();
      final firstDay = DateTime(now.year, now.month, 1);
      final lastDay = DateTime(now.year, now.month + 1, 0);
      await loadAllRecordsForMonth(firstDay, lastDay);
    } catch (e) {
      debugPrint('加载打卡目标失败: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadAllRecordsForMonth(DateTime startDate, DateTime endDate) async {
    try {
      _completedGoalIds.clear();
      for (var goal in _goals) {
        if (goal.id != null) {
          final records = await DatabaseService.instance.getHabitRecords(goal.id!, startDate, endDate);
          _records[goal.id!] = records;
          
          for (var record in records) {
            if (record.isCompleted == 1) {
              final date = DateTime.parse(record.date);
              if (!_completedGoalIds.containsKey(date)) {
                _completedGoalIds[date] = {};
              }
              _completedGoalIds[date]!.add(record.goalId);
            }
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('加载打卡记录失败: $e');
    }
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

  Set<int> getCompletedGoalIdsForDate(DateTime date) {
    final dateKey = DateTime(date.year, date.month, date.day);
    return _completedGoalIds[dateKey] ?? {};
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
      
      // 从完成记录中移除
      for (var date in _completedGoalIds.keys) {
        _completedGoalIds[date]!.remove(id);
      }
      
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
      
      if (record.isCompleted == 1) {
        final date = DateTime.parse(record.date);
        if (!_completedGoalIds.containsKey(date)) {
          _completedGoalIds[date] = {};
        }
        _completedGoalIds[date]!.add(record.goalId);
      }
      
      notifyListeners();
      return id;
    } catch (e) {
      debugPrint('添加打卡记录失败: $e');
      rethrow;
    }
  }

  Future<void> toggleHabit(int goalId, DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      final records = getRecords(goalId);
      HabitRecord? existingRecord;
      
      for (var record in records) {
        if (record.date == dateStr) {
          existingRecord = record;
          break;
        }
      }
      
      if (existingRecord != null) {
        // 切换现有记录的状态
        existingRecord.isCompleted = existingRecord.isCompleted == 1 ? 0 : 1;
        await DatabaseService.instance.updateHabitRecord(existingRecord);
        
        final dateKey = DateTime(date.year, date.month, date.day);
        if (existingRecord.isCompleted == 1) {
          if (!_completedGoalIds.containsKey(dateKey)) {
            _completedGoalIds[dateKey] = {};
          }
          _completedGoalIds[dateKey]!.add(goalId);
        } else {
          _completedGoalIds[dateKey]?.remove(goalId);
        }
      } else {
        // 创建新记录
        final now = DateTime.now();
        final record = HabitRecord(
          goalId: goalId,
          date: dateStr,
          isCompleted: 1,
          createdAt: now.toIso8601String(),
        );
        await addRecord(record);
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('切换打卡状态失败: $e');
      rethrow;
    }
  }

  bool isCompleted(int goalId, DateTime date) {
    final dateKey = DateTime(date.year, date.month, date.day);
    return _completedGoalIds[dateKey]?.contains(goalId) ?? false;
  }

  /// 判断某个目标在指定日期是否应该显示（根据频率计算）
  bool shouldShowOnDate(HabitGoal goal, DateTime date) {
    // startDate 之前不显示
    try {
      final start = DateTime.parse(goal.startDate);
      if (date.isBefore(DateTime(start.year, start.month, start.day))) {
        return false;
      }
    } catch (_) {}

    switch (goal.frequency) {
      case 'daily':
        return true;
      case 'weekdays':
        // 工作日：考虑中国节假日
        return HolidayService().isWorkday(date);
      case 'weekly':
        // 每周一次 —— 以周日为每周目标日（用户习惯以周末为一周之末）
        // 这里简单处理：每天都显示（让用户自己选一个时间打卡）
        return true;
      case 'custom':
        if (goal.targetDays == null || goal.targetDays!.isEmpty) return true;
        final selected = goal.targetDays!.split(',').map((e) => int.tryParse(e)).whereType<int>().toSet();
        return selected.contains(date.weekday);
      case 'interval':
        final interval = goal.customIntervalDays;
        if (interval == null || interval < 1) return true;
        try {
          final start = DateTime.parse(goal.startDate);
          final startDay = DateTime(start.year, start.month, start.day);
          final targetDay = DateTime(date.year, date.month, date.day);
          final diff = targetDay.difference(startDay).inDays;
          // diff 是 0, interval, 2*interval ... 的日子才显示
          return diff % interval == 0;
        } catch (_) {
          return true;
        }
      default:
        return true;
    }
  }
}
