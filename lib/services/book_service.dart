import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book.dart';

class BookService {
  static final BookService instance = BookService._();
  BookService._();

  static const _prefsKey = 'chihiro_books';
  static const _activeKey = 'chihiro_active_book';

  int? _currentBookId;
  List<Book>? _books;

  Future<void> _load() async {
    if (_books != null) return;
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKey);
    if (json != null && json.isNotEmpty) {
      final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
      _books = list.map((e) => Book.fromJson(Map<String, dynamic>.from(e))).toList();
    } else {
      _books = [];
    }
    _currentBookId = prefs.getInt(_activeKey);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_books!.map((b) => b.toJson()).toList());
    await prefs.setString(_prefsKey, json);
    if (_currentBookId != null) {
      await prefs.setInt(_activeKey, _currentBookId!);
    }
  }

  int get _nextId {
    int maxId = 0;
    for (final b in _books!) {
      if (b.id > maxId) maxId = b.id;
    }
    return maxId + 1;
  }

  /// 获取数据库文件目录
  static Future<String> getDbDir() async {
    final docDir = await getApplicationDocumentsDirectory();
    return docDir.path;
  }

  /// 获取指定账本的数据库文件路径
  static Future<String> getDbPath(int bookId) async {
    final dir = await getDbDir();
    return p.join(dir, 'chihiro_book_$bookId.db');
  }

  // ------- 公开 API -------

  Future<List<Book>> getBooksForAccount(int accountId) async {
    await _load();
    return _books!.where((b) => b.accountId == accountId).toList();
  }

  Future<Book?> getCurrentBook() async {
    await _load();
    if (_currentBookId == null) return null;
    try {
      return _books!.firstWhere((b) => b.id == _currentBookId);
    } catch (_) {
      return null;
    }
  }

  /// 创建新账本（同时创建独立的 .db 文件 + 默认分类）
  Future<Book> createBook(int accountId, String name) async {
    await _load();
    if (name.trim().isEmpty) throw Exception('账本名称不能为空');
    if (_books!.any((b) => b.accountId == accountId && b.name == name.trim())) {
      throw Exception('账本名称已存在');
    }

    final book = Book(
      id: _nextId,
      accountId: accountId,
      name: name.trim(),
      createdAt: DateTime.now(),
    );
    _books!.add(book);
    await _save();

    // 初始化独立数据库文件并创建默认分类
    await _initBookDatabase(book.id);
    return book;
  }

  /// 切换账本
  Future<void> switchBook(int bookId) async {
    await _load();
    final exists = _books!.any((b) => b.id == bookId);
    if (!exists) throw Exception('账本不存在');
    _currentBookId = bookId;
    await _save();
  }

  /// 删除账本（同时删除 .db 文件）
  Future<void> deleteBook(int bookId) async {
    await _load();
    _books!.removeWhere((b) => b.id == bookId);

    // 删除数据库文件
    try {
      final dbPath = await getDbPath(bookId);
      final file = File(dbPath);
      if (await file.exists()) await file.delete();
    } catch (_) {}

    // 如果删除的是当前账本，切换到该账号的其他账本
    if (_currentBookId == bookId) {
      final remaining = _books!.where((b) => b.accountId == (_currentAccountId())).toList();
      _currentBookId = remaining.isNotEmpty ? remaining.first.id : null;
    }
    await _save();
  }

  /// 删除某账号下所有账本
  Future<void> deleteAllBooksForAccount(int accountId) async {
    await _load();
    final toDelete = _books!.where((b) => b.accountId == accountId).toList();
    for (final book in toDelete) {
      try {
        final dbPath = await getDbPath(book.id);
        final file = File(dbPath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    _books!.removeWhere((b) => b.accountId == accountId);
    if (toDelete.any((b) => b.id == _currentBookId)) {
      _currentBookId = null;
    }
    await _save();
  }

  /// 重命名账本
  Future<void> renameBook(int bookId, String newName) async {
    await _load();
    if (newName.trim().isEmpty) throw Exception('名称不能为空');
    final book = _books!.firstWhere((b) => b.id == bookId,
        orElse: () => throw Exception('账本不存在'));

    final idx = _books!.indexWhere((b) => b.id == bookId);
    _books![idx] = Book(
      id: book.id,
      accountId: book.accountId,
      name: newName.trim(),
      createdAt: book.createdAt,
    );
    await _save();
  }

  /// 导出所有账本数据为 JSON
  Future<List<Map<String, dynamic>>> exportAllForAccount(int accountId) async {
    await _load();
    final books = _books!.where((b) => b.accountId == accountId).toList();
    return books.map((b) => b.toJson()).toList();
  }

  int? _currentAccountId() {
    final candidates = _books!.where((b) => b.id == _currentBookId).toList();
    return candidates.isNotEmpty ? candidates.first.accountId : null;
  }

  // ------- 数据库初始化 -------
  // （DBHelper 具体建表逻辑；这里只负责触发）

  Future<void> _initBookDatabase(int bookId) async {
    final dbPath = await getDbPath(bookId);
    // 复用 DBHelper 的建表逻辑
    // （通过 DBHelper.instance.initBookDb 完成建表 + 默认分类写入）
    await _createNewBookDb(dbPath);
  }

  Future<void> _createNewBookDb(String dbPath) async {
    // 这个函数由 DBHelper 调用建表 SQL
    // 暂时留空，等 DBHelper 重构后由 DBHelper.initBookDb 处理
    // BookService 只负责协调和管理元数据
  }
}
