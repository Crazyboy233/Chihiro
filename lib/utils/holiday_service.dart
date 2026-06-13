import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 节假日信息
class HolidayInfo {
  /// 节假日名称（如 "春节"、"劳动节"）
  final String name;

  /// 是否为法定节假日（放假，无需打卡）
  final bool isHoliday;

  /// 是否为调休补班日（周末要上班）
  final bool isMakeupWorkday;

  HolidayInfo({
    required this.name,
    required this.isHoliday,
    required this.isMakeupWorkday,
  });

  HolidayInfo.none()
      : name = '',
        isHoliday = false,
        isMakeupWorkday = false;

  @override
  String toString() =>
      'HolidayInfo(name=$name, isHoliday=$isHoliday, isMakeupWorkday=$isMakeupWorkday)';
}

/// 中国法定节假日服务
/// - 内置 2025-2026 年完整节假日和调休数据（国务院公告）
/// - 支持在线刷新后续年份（可选，失败不影响使用）
/// - 数据缓存到本地文件，下次启动优先读缓存
class HolidayService {
  static final HolidayService _instance = HolidayService._internal();

  factory HolidayService() => _instance;

  HolidayService._internal();

  /// dateString(yyyy-MM-dd) -> HolidayInfo
  final Map<String, HolidayInfo> _cache = {};

  bool _isInitialized = false;
  bool _hasTriedOnlineRefresh = false; // 本次会话内已尝试过在线刷新

  bool get isInitialized => _isInitialized;

  // ========== 内置节假日数据（国务院公告）==========

  // 法定节假日（放假日期）
  // 格式：yyyy-MM-dd -> 节假日名称
  static const Map<String, String> _builtInHolidays = {
    // 2025 年
    '2025-01-01': '元旦',
    '2025-01-29': '春节',
    '2025-01-30': '春节',
    '2025-01-31': '春节',
    '2025-02-01': '春节',
    '2025-02-02': '春节',
    '2025-02-03': '春节',
    '2025-02-04': '春节',
    '2025-04-04': '清明',
    '2025-04-05': '清明',
    '2025-04-06': '清明',
    '2025-05-01': '劳动节',
    '2025-05-02': '劳动节',
    '2025-05-03': '劳动节',
    '2025-05-04': '劳动节',
    '2025-05-05': '劳动节',
    '2025-05-31': '端午',
    '2025-06-01': '端午',
    '2025-06-02': '端午',
    '2025-10-01': '国庆',
    '2025-10-02': '国庆',
    '2025-10-03': '国庆',
    '2025-10-04': '国庆',
    '2025-10-05': '国庆',
    '2025-10-06': '中秋',
    '2025-10-07': '国庆',

    // 2026 年
    '2026-01-01': '元旦',
    '2026-01-02': '元旦',
    '2026-01-03': '元旦',
    '2026-02-17': '春节',
    '2026-02-18': '春节',
    '2026-02-19': '春节',
    '2026-02-20': '春节',
    '2026-02-21': '春节',
    '2026-02-22': '春节',
    '2026-02-23': '春节',
    '2026-04-04': '清明',
    '2026-04-05': '清明',
    '2026-04-06': '清明',
    '2026-05-01': '劳动节',
    '2026-05-02': '劳动节',
    '2026-05-03': '劳动节',
    '2026-05-04': '劳动节',
    '2026-05-05': '劳动节',
    '2026-06-19': '端午',
    '2026-06-20': '端午',
    '2026-06-21': '端午',
    '2026-09-25': '中秋',
    '2026-09-26': '中秋',
    '2026-09-27': '中秋',
    '2026-10-01': '国庆',
    '2026-10-02': '国庆',
    '2026-10-03': '国庆',
    '2026-10-04': '国庆',
    '2026-10-05': '国庆',
    '2026-10-06': '国庆',
    '2026-10-07': '国庆',
  };

  // 调休补班日（周末变工作日）
  // 格式：yyyy-MM-dd -> 调休说明
  static const Map<String, String> _builtInMakeupWorkdays = {
    // 2025 年调休
    '2025-01-26': '春节调休',
    '2025-02-08': '春节调休',
    '2025-04-27': '劳动节调休',
    '2025-05-10': '劳动节调休',
    '2025-09-28': '国庆调休',
    '2025-10-11': '国庆调休',

    // 2026 年调休
    '2026-02-15': '春节调休',
    '2026-02-28': '春节调休',
    '2026-04-26': '劳动节调休',
    '2026-05-09': '劳动节调休',
    '2026-09-27': '中秋/国庆调休',
    '2026-10-10': '国庆调休',
  };

  // ========== 初始化与缓存 ==========

  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    await _loadFromCacheOrBuiltIn();
    _isInitialized = true;
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _loadFromCacheOrBuiltIn() async {
    _cache.clear();
    // 先加载内置数据
    _builtInHolidays.forEach((dateStr, name) {
      _cache[dateStr] = HolidayInfo(
        name: name,
        isHoliday: true,
        isMakeupWorkday: false,
      );
    });
    _builtInMakeupWorkdays.forEach((dateStr, name) {
      _cache[dateStr] = HolidayInfo(
        name: name,
        isHoliday: false,
        isMakeupWorkday: true,
      );
    });

    // 再尝试从本地文件合并用户缓存的数据
    try {
      final file = await _getCacheFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        data.forEach((dateStr, value) {
          if (value is Map<String, dynamic>) {
            _cache[dateStr] = HolidayInfo(
              name: value['name'] as String? ?? '',
              isHoliday: value['isHoliday'] as bool? ?? false,
              isMakeupWorkday: value['isMakeupWorkday'] as bool? ?? false,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('加载节假日缓存失败: $e');
    }
  }

  Future<File?> _getCacheFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cachePath = p.join(dir.path, 'holidays_cache.json');
      return File(cachePath);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCacheToFile() async {
    try {
      final file = await _getCacheFile();
      if (file == null) return;
      final Map<String, dynamic> output = {};
      _cache.forEach((key, value) {
        output[key] = {
          'name': value.name,
          'isHoliday': value.isHoliday,
          'isMakeupWorkday': value.isMakeupWorkday,
        };
      });
      await file.writeAsString(jsonEncode(output));
    } catch (e) {
      debugPrint('保存节假日缓存失败: $e');
    }
  }

  // ========== 查询接口 ==========

  /// 获取指定日期的节假日信息
  HolidayInfo getHolidayInfo(DateTime date) {
    final dateStr = _formatDate(date);
    return _cache[dateStr] ?? HolidayInfo.none();
  }

  /// 是否为法定节假日（放假）
  bool isPublicHoliday(DateTime date) {
    return getHolidayInfo(date).isHoliday;
  }

  /// 是否为调休补班日（周末要上班）
  bool isMakeupWorkday(DateTime date) {
    return getHolidayInfo(date).isMakeupWorkday;
  }

  /// 获取节假日名称（如果是）
  String? getHolidayName(DateTime date) {
    final info = getHolidayInfo(date);
    if (info.name.isEmpty) return null;
    return info.name;
  }

  /// 是否为"应该打卡的工作日"（用于工作日频率判断）
  /// 逻辑：
  /// - 调休补班日 → 是工作日
  /// - 法定节假日 → 不是工作日
  /// - 其他：周一到周五 → 是工作日
  bool isWorkday(DateTime date) {
    final info = getHolidayInfo(date);
    if (info.isHoliday) return false;
    if (info.isMakeupWorkday) return true;
    final w = date.weekday;
    return w >= 1 && w <= 5;
  }

  // ========== 在线刷新（可选，失败静默）==========

  /// 尝试从在线 API 刷新后续年份的节假日数据
  /// 失败不影响使用（仍用内置数据）
  /// 注意：本次会话内只尝试一次，避免频繁请求导致超时日志刷屏
  Future<bool> tryRefreshOnline({int timeoutSeconds = 5}) async {
    // 本次会话内已经尝试过 → 直接返回，不再重复请求
    if (_hasTriedOnlineRefresh) return false;
    _hasTriedOnlineRefresh = true;

    try {
      final now = DateTime.now();
      final year = now.year;
      // 尝试拉取当前年和下一年的数据
      for (var y in [year, year + 1]) {
        await _fetchYearFromNagerAt(y, timeoutSeconds: timeoutSeconds);
      }
      await _saveCacheToFile();
      return true;
    } catch (e) {
      // 失败静默处理：只在 debug 模式下打印一次简短提示，不打扰用户
      debugPrint('节假日在线刷新失败（将使用内置数据）: $e');
      return false;
    }
  }

  /// 从 Nager.Date API 拉取（这个 API 只返回法定假日日期，没有调休信息）
  /// 用于填补内置数据以外的年份
  Future<void> _fetchYearFromNagerAt(int year, {int timeoutSeconds = 5}) async {
    // 如果这一年已经在内置数据里（有完整节假日+调休），跳过
    final hasBuiltIn = _builtInHolidays.keys.any((d) => d.startsWith('$year-')) ||
        _builtInMakeupWorkdays.keys.any((d) => d.startsWith('$year-'));
    if (hasBuiltIn) {
      // 不覆盖内置数据（内置数据更准确，含调休信息）
      return;
    }

    final url = 'https://date.nager.at/api/v3/PublicHolidays/$year/CN';
    final response = await http
        .get(Uri.parse(url))
        .timeout(Duration(seconds: timeoutSeconds));

    if (response.statusCode != 200) return;

    final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
    for (var item in list) {
      final dateStr = item['date'] as String?;
      final localName = item['localName'] as String?;
      final name = item['name'] as String?;
      if (dateStr == null) continue;
      // Nager 对中国节假日的中文/英文名可能不准确，优先取 localName
      final display = (localName != null && localName.isNotEmpty)
          ? localName
          : (name ?? '节假日');
      // 只在当前没有这条记录时写入（不覆盖本地已有数据）
      if (!_cache.containsKey(dateStr)) {
        _cache[dateStr] = HolidayInfo(
          name: display,
          isHoliday: true,
          isMakeupWorkday: false,
        );
      }
    }
  }
}
