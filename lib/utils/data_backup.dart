import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

/// 数据导出/导入工具
/// - 导出：把数据库所有表的数据读出来，保存为 JSON 文件
/// - 导入：从 JSON 文件读取数据，清空旧表后写入
/// 作用：换包名/重装/换机时不丢失数据
class DataBackup {
  static const _backupVersion = 1;

  /// 要导出/导入的表（按依赖顺序排列，先写主表，后写有外键的表）
  static const List<String> _tableOrder = [
    'categories',
    'schedule_categories',
    'habit_goals',
    'transactions',
    'schedules',
    'habit_records',
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
    final fileName = 'chihiro_backup_${DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0]}.json';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(backup),
      encoding: utf8,
    );

    return file.path;
  }

  // ============================================================
  // 导入
  // ============================================================

  /// 从 JSON 文件导入数据（会清空当前所有数据）
  /// 返回：导入的记录总数
  static Future<int> importFromFile(String filePath) async {
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
    int totalImported = 0;

    // 用事务保证整体成功
    await db.transaction((txn) async {
      // 1. 先清空所有表（按相反顺序删除，避免外键约束问题）
      for (final table in _tableOrder.reversed) {
        await txn.delete(table);
      }

      // 2. 按顺序写入
      for (final table in _tableOrder) {
        final rows = tables[table] as List<dynamic>?;
        if (rows == null || rows.isEmpty) continue;

        for (final row in rows) {
          final map = Map<String, dynamic>.from(row as Map);
          // 去掉 id 字段，让新库重新生成自增 id（除了被外键引用的 id 需要保持一致）
          // 这里我们保留 id 以维持依赖关系（事务里 id 不会被重置，所以可以直接保留）
          await txn.insert(table, map, conflictAlgorithm: ConflictAlgorithm.replace);
          totalImported++;
        }
      }
    });

    return totalImported;
  }

  // ============================================================
  // 文件目录与扫描
  // ============================================================

  /// 获取备份文件保存的目录（应用外部存储目录，用户可访问）
  static Future<Directory> _getBackupDirectory() async {
    Directory dir;
    try {
      // Android 优先用应用外部存储目录（用户可通过文件管理器访问）
      final externalDirs = await getExternalStorageDirectories();
      if (externalDirs != null && externalDirs.isNotEmpty) {
        dir = Directory(p.join(externalDirs.first.path, 'Backup'));
      } else {
        // iOS / Windows / 其他平台
        final docDir = await getApplicationDocumentsDirectory();
        dir = Directory(p.join(docDir.path, 'Backup'));
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

  /// 获取备份目录的用户可读路径（用于在 UI 上显示）
  static Future<String> getBackupDirectoryPath() async {
    final dir = await _getBackupDirectory();
    return dir.path;
  }
}
