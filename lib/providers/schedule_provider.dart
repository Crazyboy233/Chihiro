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
      final scheduleDate = schedule.startTime.split('T')[0];
      return scheduleDate == dateStr;
    }).toList();
  }
}
