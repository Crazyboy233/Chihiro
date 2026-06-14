import 'package:intl/intl.dart';

class DateUtils {
  static String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
  }

  static String formatMonth(DateTime date) {
    return DateFormat('yyyy年MM月').format(date);
  }

  static String formatDay(DateTime date) {
    return DateFormat('MM月dd日').format(date);
  }

  static String formatDayWithWeekday(DateTime date) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${formatDay(date)} ${weekdays[date.weekday - 1]}';
  }

  static DateTime getStartOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  static DateTime getEndOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0, 23, 59, 59);
  }

  static DateTime getStartOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  static DateTime getEndOfWeek(DateTime date) {
    return date.add(Duration(days: DateTime.daysPerWeek - date.weekday));
  }

  static DateTime getStartOfYear(DateTime date) {
    return DateTime(date.year, 1, 1);
  }

  static DateTime getEndOfYear(DateTime date) {
    return DateTime(date.year, 12, 31, 23, 59, 59);
  }

  static String getCurrentTimestamp() {
    return DateTime.now().toIso8601String();
  }

  static DateTime getBeijingTime() {
    final now = DateTime.now();
    return now.toUtc().add(const Duration(hours: 8));
  }

  static DateTime parseDate(String dateStr) {
    // 注意：DateTime.parse("YYYY-MM-DD") 会解析为 UTC 时间
    // 这里手动解析为本地时间，以确保与其他日期计算保持一致
    final parts = dateStr.split('-');
    if (parts.length >= 3) {
      return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    }
    // 回退到默认解析（处理异常情况
    final fallback = DateTime.parse(dateStr);
    return DateTime(fallback.year, fallback.month, fallback.day);
  }

  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
