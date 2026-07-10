import 'package:flutter/foundation.dart';
import '../models/schedule.dart';
import '../services/database_service.dart';

class ScheduleProvider with ChangeNotifier {
  List<Schedule> _schedules = [];
  bool _isLoading = false;

  List<Schedule> get schedules => _schedules;
  bool get isLoading => _isLoading;

  Future<void> loadSchedules(DateTime startDate, DateTime endDate) async {
    _isLoading = true;
    notifyListeners();

    try {
      _schedules = await DatabaseService.instance.getSchedulesByDateRange(startDate, endDate);
    } catch (e) {
      debugPrint('加载日程失败: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<int> addSchedule(Schedule schedule) async {
    try {
      final id = await DatabaseService.instance.insertSchedule(schedule);
      schedule.id = id;
      _schedules.add(schedule);
      _schedules.sort((a, b) => a.startTime.compareTo(b.startTime));
      notifyListeners();
      return id;
    } catch (e) {
      debugPrint('添加日程失败: $e');
      rethrow;
    }
  }

  Future<void> updateSchedule(Schedule schedule) async {
    try {
      await DatabaseService.instance.updateSchedule(schedule);
      final index = _schedules.indexWhere((s) => s.id == schedule.id);
      if (index != -1) {
        _schedules[index] = schedule;
        _schedules.sort((a, b) => a.startTime.compareTo(b.startTime));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('更新日程失败: $e');
      rethrow;
    }
  }

  Future<void> deleteSchedule(int id) async {
    try {
      await DatabaseService.instance.deleteSchedule(id);
      _schedules.removeWhere((s) => s.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('删除日程失败: $e');
      rethrow;
    }
  }

  List<Schedule> getSchedulesByDate(DateTime date) {
    final dateStr = date.toIso8601String().split('T')[0];
    return _schedules.where((schedule) {
      final startDate = schedule.startTime.split('T')[0];
      if (schedule.endTime != null && schedule.endTime!.isNotEmpty) {
        final endDate = schedule.endTime!.split('T')[0];
        return dateStr.compareTo(startDate) >= 0 && dateStr.compareTo(endDate) <= 0;
      }
      return startDate == dateStr;
    }).toList();
  }

  /// 判断日程是否跨天（startTime 和 endTime 日期不同）
  bool isMultiDay(Schedule schedule) {
    if (schedule.endTime == null || schedule.endTime!.isEmpty) return false;
    final startDate = schedule.startTime.split('T')[0];
    final endDate = schedule.endTime!.split('T')[0];
    return startDate != endDate;
  }

  /// 获取与指定周有交集的跨天日程
  List<Schedule> getMultiDaySchedulesForWeek(List<DateTime> weekDays) {
    if (weekDays.isEmpty) return [];
    final weekStart = weekDays.first;
    final weekEnd = weekDays.last;
    final weekStartStr = weekStart.toIso8601String().split('T')[0];
    final weekEndStr = weekEnd.toIso8601String().split('T')[0];

    return _schedules.where((schedule) {
      if (!isMultiDay(schedule)) return false;
      final startDate = schedule.startTime.split('T')[0];
      final endDate = schedule.endTime!.split('T')[0];
      return startDate.compareTo(weekEndStr) <= 0 && endDate.compareTo(weekStartStr) >= 0;
    }).toList();
  }
}
