import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/countdown_day.dart';
import '../services/database_service.dart';
import '../utils/db_helper.dart';
import '../utils/holiday_service.dart';

/// 假期分组（同名节假日，间隔 ≤3 天视为同一假期，如 2025 国庆/中秋连休）
class _HolidayGroup {
  final String name;
  final DateTime start;
  DateTime end;

  _HolidayGroup(this.name, this.start, this.end);

  int get days => end.difference(start).inDays + 1;
}

class CountdownProvider with ChangeNotifier {
  List<CountdownDay> _days = [];
  bool _isLoading = false;

  List<CountdownDay> get days => _days;
  bool get isLoading => _isLoading;

  /// 各节假日的默认颜色
  static const Map<String, String> _holidayColors = {
    '元旦': '#0EA5E9',
    '春节': '#EF4444',
    '清明': '#10B981',
    '劳动节': '#F59E0B',
    '端午': '#059669',
    '中秋': '#EAB308',
    '国庆': '#F43F5E',
  };

  Future<void> loadCountdownDays() async {
    _isLoading = true;
    notifyListeners();

    try {
      _days = await DatabaseService.instance.getCountdownDays();
      await _seedDefaultHolidays();
    } catch (e) {
      // 数据库未就绪等情况静默失败，页面显示空态
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<int> addCountdownDay(CountdownDay day) async {
    try {
      final id = await DatabaseService.instance.insertCountdownDay(day);
      day.id = id;
      _days.add(day);
      _sort();
      notifyListeners();
      return id;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateCountdownDay(CountdownDay day) async {
    try {
      await DatabaseService.instance.updateCountdownDay(day);
      final index = _days.indexWhere((d) => d.id == day.id);
      if (index != -1) {
        _days[index] = day;
        _sort();
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteCountdownDay(int id) async {
    try {
      await DatabaseService.instance.deleteCountdownDay(id);
      _days.removeWhere((d) => d.id == id);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  void _sort() {
    _days.sort((a, b) => a.targetDate.compareTo(b.targetDate));
  }

  // ============ 默认节假日种子 ============

  /// 自动补充国内法定节假日倒数（按账号记录已种子过的假期，删了不会回来）
  ///
  /// - 数据来源 HolidayService（内置国务院公告数据 + 在线缓存）
  /// - 只补"今天及以后"的假期起始日
  /// - 每个假期实例（起始日+名称）只种子一次，用户删除后不再出现
  Future<void> _seedDefaultHolidays() async {
    try {
      final accountId = DBHelper.instance.activeAccountId;
      if (accountId == null) return;

      await HolidayService().ensureInitialized();

      final prefs = await SharedPreferences.getInstance();
      final prefKey = 'countdown_holiday_seeded_$accountId';
      final seeded = (prefs.getStringList(prefKey) ?? []).toSet();

      final groups = _collectUpcomingHolidays();
      if (groups.isEmpty) return;

      final now = DateTime.now().toIso8601String();
      var changed = false;

      for (final g in groups) {
        final dateStr = _formatDate(g.start);
        final seedKey = '$dateStr|${g.name}';
        if (seeded.contains(seedKey)) continue;
        seeded.add(seedKey);

        // 同日起始、同名条已存在（用户自己建过）则不重复添加
        final exists = _days.any(
          (d) => d.targetDate == dateStr && d.title == g.name,
        );
        if (exists) continue;

        final id = await DatabaseService.instance.insertCountdownDay(
          CountdownDay(
            title: g.name,
            targetDate: dateStr,
            type: CountdownDay.typeCountdown,
            color: _holidayColors[g.name] ?? '#6366F1',
            note: g.days > 1
                ? '${g.start.month}月${g.start.day}日至${g.end.month}月${g.end.day}日 · 共${g.days}天'
                : '法定节假日',
            createdAt: now,
            updatedAt: now,
          ),
        );
        _days.add(
          CountdownDay(
            id: id,
            title: g.name,
            targetDate: dateStr,
            type: CountdownDay.typeCountdown,
            color: _holidayColors[g.name] ?? '#6366F1',
            note: g.days > 1
                ? '${g.start.month}月${g.start.day}日至${g.end.month}月${g.end.day}日 · 共${g.days}天'
                : '法定节假日',
            createdAt: now,
            updatedAt: now,
          ),
        );
        changed = true;
      }

      await prefs.setStringList(prefKey, seeded.toList());
      if (changed) _sort();
    } catch (_) {
      // 种子失败不影响正常加载
    }
  }

  /// 汇总今天起 400 天内的法定节假日，按名称分组（同名间隔 ≤3 天合并）
  List<_HolidayGroup> _collectUpcomingHolidays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final service = HolidayService();
    final groups = <_HolidayGroup>[];

    for (var i = 0; i < 400; i++) {
      final date = today.add(Duration(days: i));
      final info = service.getHolidayInfo(date);
      if (!info.isHoliday || info.name.isEmpty) continue;

      // 找同名且间隔 ≤3 天的最近分组并延长，允许跨名称连休
      // （如 2025 年 国庆10/1-5、中秋10/6、国庆10/7 → 国庆合并为 10/1-7）
      _HolidayGroup? match;
      for (final g in groups.reversed) {
        if (date.difference(g.end).inDays > 3) break; // 更早的分组间隔更大
        if (g.name == info.name) {
          match = g;
          break;
        }
      }
      if (match != null) {
        match.end = date;
      } else {
        groups.add(_HolidayGroup(info.name, date, date));
      }
    }

    // 元旦兜底：公历固定 1 月 1 日，数据缺失的年份也保证有倒数
    if (!groups.any((g) => g.name == '元旦')) {
      var newYear = DateTime(today.year, 1, 1);
      if (newYear.isBefore(today)) newYear = DateTime(today.year + 1, 1, 1);
      groups.add(_HolidayGroup('元旦', newYear, newYear));
      groups.sort((a, b) => a.start.compareTo(b.start));
    }
    return groups;
  }

  String _formatDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}
