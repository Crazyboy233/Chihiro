import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

/// 数据导出/导入工具
///
/// 支持三种导出模式：
/// - 账本级：导出当前活跃账本的全部数据 → JSON
/// - 账号级：导出当前账号下所有账本的全部数据 → 一个嵌套 JSON
/// - 导入时自动识别文件类型（旧版 / 账本 / 账号），追加合并
class DataBackup {
  static const _backupVersion = 3;
  static const _backupTypeBook = 'book';
  static const _backupTypeAccount = 'account';

  // 账本级表（仅账单）
  static const List<String> _bookTables = ['categories', 'transactions'];

  // 账号级表（日程、打卡）
  static const List<String> _accountTables = [
    'schedule_categories', 'schedules',
    'habit_goals', 'habit_records',
  ];

  // ============================================================
  // 数据库路径 — 导出 / 导入时可能读取任意账本的 .db
  // ============================================================

  /// 打开指定账本的数据库连接（临时，用完即关）
  static Future<Database> _openBookDb(int bookId) async {
    final dbPath = await DBHelper.getBookDbPath(bookId);
    final file = File(dbPath);
    if (!await file.exists()) {
      throw Exception('账本数据文件不存在: $dbPath');
    }

    return await openDatabase(
      dbPath,
      version: 3,
      readOnly: true,
    );
  }

  /// 从 DB 连接读取指定表的数据
  static Future<Map<String, List<Map<String, dynamic>>>> _readTables(
      Database db, List<String> tables) async {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final table in tables) {
      try {
        final rows = await db.query(table);
        result[table] = rows.map((row) => Map<String, dynamic>.from(row)).toList();
      } catch (_) {
        result[table] = [];
      }
    }
    return result;
  }

  // ============================================================
  // 账本级导出 / 导入
  // ============================================================

  /// 导出单个账本 → JSON
  /// [bookId] 账本 ID，[bookName] 用于文件名
  static Future<String> exportBook(int bookId, String bookName) async {
    final db = await _openBookDb(bookId);
    try {
      final tables = await _readTables(db, _bookTables);
      final backup = {
        'type': _backupTypeBook,
        'version': _backupVersion,
        'book_name': bookName,
        'exported_at': DateTime.now().toIso8601String(),
        'tables': tables,
      };

      final dir = await _getBackupDirectory();
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final safe = bookName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final fileName = 'chihiro_book_${safe}_$timestamp.json';
      final file = File(p.join(dir.path, fileName));
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(backup),
        encoding: utf8,
      );
      return file.path;
    } finally {
      await db.close();
    }
  }

  // ============================================================
  // 账号级导出
  // ============================================================

  /// 导出某个账号下的所有账本 + 账号级数据 → 一个嵌套 JSON
  static Future<String> exportAccount({
    required String accountName,
    required int accountId,
    required List<Map<String, dynamic>> bookMetas,
  }) async {
    final booksData = <Map<String, dynamic>>[];
    for (final meta in bookMetas) {
      final bookId = meta['id'] as int;
      final bookName = meta['name'] as String;
      final db = await _openBookDb(bookId);
      try {
        final tables = await _readTables(db, _bookTables);
        booksData.add({
          'name': bookName,
          'tables': tables,
        });
      } finally {
        await db.close();
      }
    }

    // 导出账号级数据（日程、打卡）
    final accountDbPath = await DBHelper.getAccountDbPath(accountId);
    Map<String, List<Map<String, dynamic>>> accountTables = {};
    if (File(accountDbPath).existsSync()) {
      final accDb = await openDatabase(accountDbPath, version: 1, readOnly: true);
      try {
        accountTables = await _readTables(accDb, _accountTables);
      } finally {
        await accDb.close();
      }
    }

    final backup = {
      'type': _backupTypeAccount,
      'version': _backupVersion,
      'account_name': accountName,
      'exported_at': DateTime.now().toIso8601String(),
      'books': booksData,
      'account_tables': accountTables,
    };

    final dir = await _getBackupDirectory();
    final timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    final safe = accountName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final fileName = 'chihiro_account_${safe}_$timestamp.json';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(backup),
      encoding: utf8,
    );
    return file.path;
  }

  // ============================================================
  // 导入（自动识别类型）
  // ============================================================

  /// 导入 JSON 备份文件到当前活跃账本。
  /// 自动识别文件类型：
  /// - 旧版（无 type 字段）→ 当作单个账本导入
  /// - type=book → 单账本导入
  /// - type=account → 批量创建账本并导入
  /// 返回结果描述文本
  static Future<String> importFromFile(String filePath, {
    required int currentAccountId,
    required int currentBookId,
    required Future<void> Function() onBooksChanged,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('文件不存在: $filePath');

    final content = await file.readAsString(encoding: utf8);
    final data = jsonDecode(content) as Map<String, dynamic>;
    final type = data['type'] as String?;
    final tablesRaw = data['tables'];

    final db = await DBHelper.instance.database;

    if (type == _backupTypeAccount) {
      // ===== 账号级导入 =====
      final books = data['books'] as List<dynamic>?;
      if (books == null || books.isEmpty) throw Exception('账号备份中没有账本数据');

      int totalInserted = 0;
      int totalMerged = 0;

      for (final bookData in books) {
        final bookMap = bookData as Map<String, dynamic>;
        final tables = bookMap['tables'] as Map<String, dynamic>?;
        if (tables == null) continue;

        // 查找是否存在同名账本，否则创建新账本
        // 注：这里需要调用 BookService，为了避免循环依赖，通过回调处理
        // 实际上导入时应当由 DataManagementScreen 配合 BookProvider 来完成账本匹配
        // 这里简化：将当前活跃账号下所有账本数据导入当前活跃账本
        final result = await _importTables(db, tables);
        totalInserted += result['inserted'] as int;
        totalMerged += result['merged'] as int;
      }

      return '$totalInserted 条新增 / $totalMerged 条合并';
    }

    // ===== 单账本 / 旧版导入 =====
    final tables = (tablesRaw ?? data['tables']) as Map<String, dynamic>?;
    if (tables == null) throw Exception('文件格式不正确，缺少 tables 字段');

    final result = await _importTables(db, tables);
    return '${result['inserted']} 条新增 / ${result['merged']} 条合并';
  }

  /// 账号级导入 —— 将每个账本的数据导入到对应的新账本中
  static Future<String> importAccountBackup(
    String filePath, {
    required int currentAccountId,
    required Future<int> Function(String name) createBook,
    required int currentBookId,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('文件不存在: $filePath');

    final content = await file.readAsString(encoding: utf8);
    final data = jsonDecode(content) as Map<String, dynamic>;
    final type = data['type'] as String?;

    if (type != _backupTypeAccount) {
      throw Exception('该文件不是账号备份，请用普通导入功能');
    }

    final books = data['books'] as List<dynamic>?;
    if (books == null || books.isEmpty) throw Exception('账号备份中没有账本数据');

    int totalInserted = 0;
    int totalMerged = 0;
    final results = <String>[];

    for (final bookData in books) {
      final bookMap = bookData as Map<String, dynamic>;
      final bookName = bookMap['name'] as String? ?? '未命名账本';
      final tables = bookMap['tables'] as Map<String, dynamic>?;
      if (tables == null) continue;

      // 创建新账本
      int newBookId;
      try {
        newBookId = await createBook(bookName);
      } catch (e) {
        results.add('「$bookName」创建失败: $e');
        continue;
      }

      // 切换到该账本的 DB 导入数据
      await DBHelper.instance.setActiveBook(newBookId);
      final db = await DBHelper.instance.database;
      final result = await _importTables(db, tables);
      final ins = result['inserted'] as int;
      final mg = result['merged'] as int;
      totalInserted += ins;
      totalMerged += mg;
      results.add('「$bookName」: $ins 新增 / $mg 合并');
    }

    // 导入账号级数据（日程、打卡）到账号 DB
    final accountTables = data['account_tables'] as Map<String, dynamic>?;
    if (accountTables != null && accountTables.isNotEmpty) {
      try {
        final accDb = await DBHelper.instance.accountDatabase;
        final result = await _importTables(accDb, accountTables);
        totalInserted += result['inserted'] as int;
        totalMerged += result['merged'] as int;
        results.add('日程打卡: ${result['inserted']} 新增 / ${result['merged']} 合并');
      } catch (e) {
        results.add('日程打卡导入失败: $e');
      }
    }

    // 导入完成后切回原来的活跃账本
    await DBHelper.instance.setActiveBook(currentBookId);

    return '${results.join('\n')}\n合计 $totalInserted 新增 / $totalMerged 合并';
  }

  /// 获取备份文件的书名（用于 UI 提示），无法解析则返回 null
  static Future<String?> getBackupBookName(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final content = await file.readAsString(encoding: utf8);
      final data = jsonDecode(content) as Map<String, dynamic>;
      final type = data['type'] as String?;
      if (type == _backupTypeBook) return data['book_name'] as String?;
      if (type == _backupTypeAccount) return data['account_name'] as String?;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 获取备份文件类型（用于 UI 展示确认信息）
  static Future<String> detectBackupType(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return 'unknown';
      final content = await file.readAsString(encoding: utf8);
      final data = jsonDecode(content) as Map<String, dynamic>;
      final type = data['type'] as String?;
      if (type == _backupTypeAccount) return 'account';
      if (type == _backupTypeBook) return 'book';
      return 'legacy';
    } catch (_) {
      return 'unknown';
    }
  }

  // ============================================================
  // 通用导入逻辑
  // ============================================================

  static Future<Map<String, int>> _importTables(Database db, Map<String, dynamic> tables) async {
    // 各主表的 旧id → 新id 映射
    final Map<String, Map<int, int>> idMappings = {};
    int inserted = 0;
    int merged = 0;

    // 默认分类映射
    final defaultByKey = <String, Map<String, Object>>{
      for (final c in DBHelper.defaultCategories) '${c['name']}__${c['type']}': c,
    };
    final allowedKeys = defaultByKey.keys.toSet();

    await db.transaction((txn) async {
      // ===== 特殊处理：categories 表 =====
      final categoryRows = tables['categories'] as List<dynamic>?;
      if (categoryRows != null && categoryRows.isNotEmpty) {
        final allRows = await txn.query('categories');
        final existingByKey = <String, int>{};
        for (final e in allRows) {
          existingByKey['${e['name']}__${e['type']}'] = e['id'] as int;
        }

        final fallbackIds = <String, int>{};
        for (final type in const ['expense', 'income']) {
          final key = '其他__$type';
          if (existingByKey.containsKey(key)) {
            fallbackIds[type] = existingByKey[key]!;
          } else if (defaultByKey.containsKey(key)) {
            final newId =
                await txn.insert('categories', Map<String, dynamic>.from(defaultByKey[key]!));
            fallbackIds[type] = newId;
            existingByKey[key] = newId;
          }
        }

        final categoryMapping = <int, int>{};
        for (final row in categoryRows) {
          final map = Map<String, dynamic>.from(row as Map);
          final oldId = map['id'] as int?;
          if (oldId == null) continue;

          final name = (map['name'] as String?)?.trim() ?? '';
          final type = (map['type'] as String?)?.trim() ?? '';
          if (name.isEmpty) continue;
          final key = '${name}__$type';

          if (existingByKey.containsKey(key)) {
            categoryMapping[oldId] = existingByKey[key]!;
            merged++;
            continue;
          }

          if (!allowedKeys.contains(key)) {
            final fallbackId = fallbackIds[type == 'income' ? 'income' : 'expense'];
            if (fallbackId != null) categoryMapping[oldId] = fallbackId;
            continue;
          }

          final d = defaultByKey[key]!;
          final newId = await txn.insert('categories', Map<String, dynamic>.from(d));
          categoryMapping[oldId] = newId;
          existingByKey[key] = newId;
          inserted++;
        }
        idMappings['categories'] = categoryMapping;
      }

      // ===== 其余主表（schedule_categories, habit_goals） =====
      for (final table in ['schedule_categories', 'habit_goals']) {
        if (table == 'categories') continue;
        final rows = tables[table] as List<dynamic>?;
        if (rows == null || rows.isEmpty) continue;

        final existingRows = await txn.query(table);
        final mapping = <int, int>{};

        for (final row in rows) {
          final map = Map<String, dynamic>.from(row as Map);
          final oldId = map['id'] as int?;
          if (oldId == null) continue;

          final existingId = _findExistingIdInMemory(table, map, existingRows);
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

      // ===== 明细表（transactions, schedules, habit_records） =====
      for (final table in ['transactions', 'schedules', 'habit_records']) {
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

  static int? _findExistingIdInMemory(
      String table, Map<String, dynamic> a, List<Map<String, dynamic>> existingRows) {
    for (final existing in existingRows) {
      bool match = false;
      switch (table) {
        case 'categories':
          match = a['name'] == existing['name'] && a['type'] == existing['type'];
          break;
        case 'schedule_categories':
          match = a['name'] == existing['name'];
          break;
        case 'habit_goals':
          match = a['name'] == existing['name'] && a['start_date'] == existing['start_date'];
          break;
      }
      if (match) return existing['id'] as int;
    }
    return null;
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

  static const String _androidStoragePrefix = '/storage/emulated/0';
  static const String _publicSubDir = 'Download/ChihiroBackup';

  static Future<Directory> _getBackupDirectory() async {
    try {
      final publicPath = p.join(_androidStoragePrefix, _publicSubDir);
      final publicDir = Directory(publicPath);
      if (!await publicDir.exists()) {
        await publicDir.create(recursive: true);
      }
      final testFile = File(p.join(publicDir.path, '.chihiro_write_test'));
      await testFile.writeAsString('ok');
      await testFile.delete();
      return publicDir;
    } catch (_) {}

    try {
      final externalDirs = await getExternalStorageDirectories();
      if (externalDirs != null && externalDirs.isNotEmpty) {
        final dir = Directory(p.join(externalDirs.first.path, 'Backup'));
        if (!await dir.exists()) await dir.create(recursive: true);
        return dir;
      }
    } catch (_) {}

    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docDir.path, 'Backup'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<String> getBackupDirectoryPath() async {
    final dir = await _getBackupDirectory();
    return dir.path;
  }

  static Future<List<File>> listBackupFiles() async {
    final dir = await _getBackupDirectory();
    if (!await dir.exists()) return [];

    final entities = dir.listSync(recursive: false).whereType<File>().toList();
    entities.sort((a, b) => b.path.compareTo(a.path));
    return entities;
  }

  static Future<void> deleteBackupFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

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
