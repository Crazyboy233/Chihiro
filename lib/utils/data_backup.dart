import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

/// 数据导出/导入工具
/// - 导出：把数据库所有表的数据读出来，保存为 JSON 文件
/// - 导入：从 JSON 文件读取数据，**追加合并**到当前数据（不删除任何现有记录）
/// - Android：优先写入公共 Download/ChihiroBackup 目录（文件管理器可见）；
///   导入使用系统文件选择器（SAF），可选择任意位置的 JSON 文件
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

  /// 导出全部数据到 JSON 文件（优先写入公共 Download/ChihiroBackup 目录）
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

    // 3. 写入文件（优先公共 Download 目录）
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
    int inserted = 0;
    int merged = 0;

    // 构建 name+type → 当前应用默认值 的映射（用于补全从鲨鱼记账等第三方导入的数据）
    // 只有在这个集合里的分类才会被写入数据库
    final defaultByKey = <String, Map<String, Object>>{
      for (final c in DBHelper.defaultCategories) '${c['name']}__${c['type']}': c,
    };
    final allowedKeys = defaultByKey.keys.toSet();

    await db.transaction((txn) async {
      // ====== 特殊处理：categories 表（去重 + 非白名单→其他 + 字段补全） ======
      // 策略：只有当前应用默认支持的分类才会被写入 categories 表。
      // 鲨鱼记账的「彩票」「快递」等未知分类，其交易将被映射到「其他」。
      final categoryRows = tables['categories'] as List<dynamic>?;
      if (categoryRows != null && categoryRows.isNotEmpty) {
        // 以 name+type 作为唯一键：先拿库里所有的分类做索引，避免重复插入
        final allRows = await txn.query('categories');
        final existingByKey = <String, int>{};
        for (final e in allRows) {
          existingByKey['${e['name']}__${e['type']}'] = e['id'] as int;
        }

        // 确保「其他」分类（expense/income）存在，供未知分类兜底映射
        final fallbackIds = <String, int>{};
        for (final type in const ['expense', 'income']) {
          final key = '其他__$type';
          if (existingByKey.containsKey(key)) {
            fallbackIds[type] = existingByKey[key]!;
          } else if (defaultByKey.containsKey(key)) {
            final newId = await txn.insert('categories', Map<String, dynamic>.from(defaultByKey[key]!));
            fallbackIds[type] = newId;
            existingByKey[key] = newId;
          }
        }

        // 遍历导入文件中的分类，逐个建立 旧id → 新id 映射
        final categoryMapping = <int, int>{};
        for (final row in categoryRows) {
          final map = Map<String, dynamic>.from(row as Map);
          final oldId = map['id'] as int?;
          if (oldId == null) continue;

          final name = (map['name'] as String?)?.trim() ?? '';
          final type = (map['type'] as String?)?.trim() ?? '';
          if (name.isEmpty) continue;
          final key = '${name}__$type';

          // 库里已有同名分类 → 复用其 id
          if (existingByKey.containsKey(key)) {
            categoryMapping[oldId] = existingByKey[key]!;
            merged++;
            continue;
          }

          // 非白名单分类 → 映射到「其他」，不新增分类
          if (!allowedKeys.contains(key)) {
            final fallbackId = fallbackIds[type == 'income' ? 'income' : 'expense'];
            if (fallbackId != null) {
              categoryMapping[oldId] = fallbackId;
            }
            continue;
          }

          // 白名单分类且库里没有 → 插入（强制使用当前应用的 icon/color 等字段）
          final d = defaultByKey[key]!;
          final newId = await txn.insert('categories', Map<String, dynamic>.from(d));
          categoryMapping[oldId] = newId;
          existingByKey[key] = newId;
          inserted++;
        }
        idMappings['categories'] = categoryMapping;
      }

      // ====== 第一轮：处理其余主表 ======
      for (final table in _masterTables) {
        if (table == 'categories') continue; // 已单独处理
        final rows = tables[table] as List<dynamic>?;
        if (rows == null || rows.isEmpty) continue;

        final existingRows = await txn.query(table);
        final mapping = <int, int>{};

        for (final row in rows) {
          final map = Map<String, dynamic>.from(row as Map);
          final oldId = map['id'] as int?;
          if (oldId == null) continue;

          final existingId = await _findExistingId(txn, table, map, existingRows);
          if (existingId != null) {
            mapping[oldId] = existingId;
            merged++;
          } else {
            final copy = Map<String, dynamic>.from(map);
            copy.remove('id');
            final newId = await txn.insert(table, copy);
            mapping[oldId] = newId;
            inserted++;
          }
        }
        idMappings[table] = mapping;
      }

      // ====== 第二轮：处理明细表 ======
      for (final table in _detailTables) {
        final rows = tables[table] as List<dynamic>?;
        if (rows == null || rows.isEmpty) continue;

        final masterTable = _getMasterTableForDetail(table);
        final mapping = idMappings[masterTable] ?? {};
        final fkColumn = _getFkColumnForDetail(table);

        for (final row in rows) {
          final map = Map<String, dynamic>.from(row as Map);
          map.remove('id');
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
  // 辅助：主表去重匹配
  // ============================================================

  static Future<int?> _findExistingId(
    DatabaseExecutor txn,
    String table,
    Map<String, dynamic> newRow,
    List<Map<String, dynamic>> existingRows,
  ) async {
    for (final existing in existingRows) {
      final match = _matchesRow(table, newRow, existing);
      if (match) return existing['id'] as int;
    }
    return null;
  }

  static bool _matchesRow(String table, Map<String, dynamic> a, Map<String, dynamic> b) {
    switch (table) {
      case 'categories':
        return a['name'] == b['name'] && a['type'] == b['type'];
      case 'schedule_categories':
        return a['name'] == b['name'];
      case 'habit_goals':
        return a['name'] == b['name'] && a['start_date'] == b['start_date'];
      default:
        return false;
    }
  }

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

  /// Android 公共存储根目录
  static const String _androidStoragePrefix = '/storage/emulated/0';

  /// 公共 Download 目录下的备份子目录（文件管理器可见）
  static const String _publicSubDir = 'Download/ChihiroBackup';

  /// 获取备份文件保存目录 —— **优先写入公共 Download/ChihiroBackup 目录**
  /// 这样用户在文件管理器中直接可见，无需进入 Android/data 隐藏目录
  static Future<Directory> _getBackupDirectory() async {
    // --- 策略 1：直接写入公共 Download/ChihiroBackup（首选，Android 文件管理器可见） ---
    try {
      final publicPath = p.join(_androidStoragePrefix, _publicSubDir);
      final publicDir = Directory(publicPath);
      if (!await publicDir.exists()) {
        await publicDir.create(recursive: true);
      }
      // 写入测试：确认该目录确实可写
      final testFile = File(p.join(publicDir.path, '.chihiro_write_test'));
      await testFile.writeAsString('ok');
      await testFile.delete();
      return publicDir;
    } catch (_) {
      // 公共目录不可写，继续回退
    }

    // --- 策略 2：使用 path_provider 获取的外部存储目录（/storage/emulated/0/Android/data/com.chihiro/files） ---
    try {
      final externalDirs = await getExternalStorageDirectories();
      if (externalDirs != null && externalDirs.isNotEmpty) {
        final dir = Directory(p.join(externalDirs.first.path, 'Backup'));
        if (!await dir.exists()) await dir.create(recursive: true);
        return dir;
      }
    } catch (_) {}

    // --- 策略 3：应用沙箱 Documents 目录（最终兜底） ---
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docDir.path, 'Backup'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// 获取备份目录的完整路径（供 UI 展示/复制）
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

  // ============================================================
  // 系统文件选择器（SAF）
  // ============================================================

  /// 调用系统文件选择器，让用户选择一个 JSON 备份文件
  /// 返回选中文件的绝对路径；用户取消则返回 null
  ///
  /// **这个方法的优点**：通过 Android SAF（存储访问框架）获得临时访问权限，
  /// 不需要任何存储权限，用户可以选择手机上任意位置的文件，
  /// 包括 /storage/emulated/0 根目录、Download、Documents、SD 卡等。
  static Future<String?> pickBackupFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json', 'JSON', 'Json'],
        dialogTitle: '选择备份文件',
      );
      if (result == null || result.files.isEmpty) return null;
      final path = result.files.single.path;
      if (path == null) throw Exception('所选文件无法被应用访问');
      return path;
    } catch (e) {
      throw Exception('选择文件失败: $e');
    }
  }
}
