import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

/// 数据导出/导入工具
/// - 导出：把数据库所有表的数据读出来，保存为 JSON 文件
/// - 导入：从 JSON 文件读取数据，**追加合并**到当前数据（不删除任何现有记录）
/// 作用：换机/重装后把旧数据合并进来；多设备数据汇总
class DataBackup {
  static const _backupVersion = 2;

  /// 主表：没有依赖其它表，有主键 id 被明细表引用
  static const List<String> _masterTables = [
    'categories',
    'schedule_categories',
    'habit_goals',
  ];

  /// 明细表：依赖主表的外键
  static const List<String> _detailTables = [
    'transactions',
    'schedules',
    'habit_records',
  ];

  /// 完整导出/导入顺序（先主后子）
  static const List<String> _tableOrder = [
    ..._masterTables,
    ..._detailTables,
  ];

  // ============================================================
  // 导出
  // ============================================================

  /// 导出全部数据到 JSON 文件
  /// 返回：导出文件的绝对路径
  static Future<String> exportAll() async {
    final db = await DBHelper.instance.database;

    // 1. 读取所有表的数据
    final Map<String, List<Map<String, dynamic>>> tables = {};
    for (final table in _tableOrder) {
      final rows = await db.query(table);
      tables[table] = rows.map((row) => Map<String, dynamic>.from(row)).toList();
    }

    // 2. 组装完整的备份对象
    final Map<String, dynamic> backup = {
      'version': _backupVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'tables': tables,
    };

    // 3. 写入文件
    final dir = await _getBackupDirectory();
    final fileName =
        'chihiro_backup_${DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0]}.json';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(backup),
      encoding: utf8,
    );

    return file.path;
  }

  // ============================================================
  // 导入（追加合并）
  // ============================================================

  /// 从 JSON 文件导入数据 —— **追加合并模式**
  /// - 不删除任何现有数据
  /// - 主表（categories / schedule_categories / habit_goals）：按名称去重，有则复用现有 id，无则新建
  /// - 明细表（transactions / schedules / habit_records）：外键 id 替换成新映射后整体插入
  /// 返回：{ 'inserted': n, 'merged': m } 两个统计数
  static Future<Map<String, int>> importFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('文件不存在: $filePath');
    }

    final content = await file.readAsString(encoding: utf8);
    final data = jsonDecode(content) as Map<String, dynamic>;

    if (data['tables'] == null) {
      throw Exception('文件格式不正确，缺少 tables 字段');
    }

    final tables = data['tables'] as Map<String, dynamic>;

    final db = await DBHelper.instance.database;

    // 各主表的 旧id → 新id 映射
    final Map<String, Map<int, int>> idMappings = {};
    int inserted = 0; // 实际新插入的记录数
    int merged = 0; // 因去重被合并复用的记录数

    await db.transaction((txn) async {
      // ====== 第一轮：处理主表（categories / schedule_categories / habit_goals）======
      for (final table in _masterTables) {
        final rows = tables[table] as List<dynamic>?;
        if (rows == null || rows.isEmpty) continue;

        // 先拿当前库中已有记录，做去重用
        final existingRows = await txn.query(table);
        final mapping = <int, int>{};

        for (final row in rows) {
          final map = Map<String, dynamic>.from(row as Map);
          final oldId = map['id'] as int?;
          if (oldId == null) continue;

          // 按字段去重匹配（不同表用不同的"判定重复"规则）
          final existingId = await _findExistingId(txn, table, map, existingRows);
          if (existingId != null) {
            // 已有同名记录 → 直接复用现有 id，不插入
            mapping[oldId] = existingId;
            merged++;
          } else {
            // 是新记录 → 去掉 id 后插入，拿到新 id
            final copy = Map<String, dynamic>.from(map);
            copy.remove('id');
            final newId = await txn.insert(table, copy);
            mapping[oldId] = newId;
            inserted++;
          }
        }
        idMappings[table] = mapping;
      }

      // ====== 第二轮：处理明细表（transactions / schedules / habit_records）======
      for (final table in _detailTables) {
        final rows = tables[table] as List<dynamic>?;
        if (rows == null || rows.isEmpty) continue;

        // 找到这张表依赖的主表（外键指向哪个主表）
        final masterTable = _getMasterTableForDetail(table);
        final mapping = idMappings[masterTable] ?? {};
        final fkColumn = _getFkColumnForDetail(table);

        for (final row in rows) {
          final map = Map<String, dynamic>.from(row as Map);
          // 去掉自己的 id，让库自增
          map.remove('id');
          // 外键替换成新 id（如果存在映射）
          if (fkColumn != null && map[fkColumn] != null) {
            final oldFk = map[fkColumn] as int;
            if (mapping[oldFk] != null) {
              map[fkColumn] = mapping[oldFk]!;
            }
          }
          await txn.insert(table, map);
          inserted++;
        }
      }
    });

    return {'inserted': inserted, 'merged': merged};
  }

  // ============================================================
  // 辅助方法：主表去重匹配
  // ============================================================

  /// 在当前库中查找是否已有"等同"记录，返回其 id；不存在则返回 null
  /// 按表的业务关键字段去匹配，而不是用 id 匹配（因为是不同库）
  static Future<int?> _findExistingId(
    DatabaseExecutor txn,
    String table,
    Map<String, dynamic> newRow,
    List<Map<String, dynamic>> existingRows,
  ) async {
    // 用内存里的 existingRows 做匹配，避免对每行都发起查询
    for (final existing in existingRows) {
      final match = _matchesRow(table, newRow, existing);
      if (match) return existing['id'] as int;
    }
    return null;
  }

  /// 判断两条记录是否"同一业务实体"（去重判定规则）
  static bool _matchesRow(String table, Map<String, dynamic> a, Map<String, dynamic> b) {
    switch (table) {
      case 'categories':
        // 同名 + 同类型 视为同一个分类
        return a['name'] == b['name'] && a['type'] == b['type'];
      case 'schedule_categories':
        // 同名日程分类视为同一分类
        return a['name'] == b['name'];
      case 'habit_goals':
        // 同名 + 同起始日 视为同一个打卡目标
        return a['name'] == b['name'] && a['start_date'] == b['start_date'];
      default:
        return false;
    }
  }

  /// 明细表对应的主表名称
  static String _getMasterTableForDetail(String table) {
    switch (table) {
      case 'transactions':
        return 'categories';
      case 'schedules':
        return 'schedule_categories';
      case 'habit_records':
        return 'habit_goals';
      default:
        return table;
    }
  }

  /// 明细表的外键字段名
  static String? _getFkColumnForDetail(String table) {
    switch (table) {
      case 'transactions':
        return 'category_id';
      case 'schedules':
        return 'category_id';
      case 'habit_records':
        return 'goal_id';
      default:
        return null;
    }
  }

  // ============================================================
  // 文件目录与扫描
  // ============================================================

  /// Android 备份文件的固定前缀（主流机型通用，文件管理器可见）
  static const String _androidStoragePrefix = '/storage/emulated/0';

  /// Android 应用包名对应的外部存储路径
  static const String _androidPackageSuffix = 'Android/data/com.chihiro/files/Backup';

  /// 获取备份文件保存的目录
  /// - Android: 固定路径 `/storage/emulated/0/Android/data/com.chihiro/files/Backup`
  /// - iOS/Windows: 应用沙箱文档目录下的 Backup 文件夹
  static Future<Directory> _getBackupDirectory() async {
    Directory dir;
    try {
      // Android 优先使用固定路径，保证所有机型路径一致，用户方便查找
      final androidPath = p.join(_androidStoragePrefix, _androidPackageSuffix);
      final androidDir = Directory(androidPath);
      // 尝试在 Android 路径下创建目录来检测是否可用
      try {
        if (!await androidDir.exists()) {
          await androidDir.create(recursive: true);
        }
        dir = androidDir;
      } catch (_) {
        // 固定路径不可用时（如 iOS/Windows），回退到平台默认的应用目录
        final externalDirs = await getExternalStorageDirectories();
        if (externalDirs != null && externalDirs.isNotEmpty) {
          dir = Directory(p.join(externalDirs.first.path, 'Backup'));
        } else {
          final docDir = await getApplicationDocumentsDirectory();
          dir = Directory(p.join(docDir.path, 'Backup'));
        }
      }
    } catch (_) {
      final docDir = await getApplicationDocumentsDirectory();
      dir = Directory(p.join(docDir.path, 'Backup'));
    }

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 获取备份目录的完整路径（供 UI 展示 / 复制 / 默认填充）
  static Future<String> getBackupDirectoryPath() async {
    final dir = await _getBackupDirectory();
    return dir.path;
  }

  /// 获取当前备份目录下的所有备份文件（按时间倒序）
  static Future<List<File>> listBackupFiles() async {
    final dir = await _getBackupDirectory();
    if (!await dir.exists()) return [];

    final entities = dir.listSync(recursive: false).whereType<File>().toList();
    entities.sort((a, b) => b.path.compareTo(a.path));
    return entities;
  }

  /// 删除指定的备份文件
  static Future<void> deleteBackupFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
