import 'package:flutter/foundation.dart';
import '../models/book.dart';
import '../services/book_service.dart';
import '../utils/db_helper.dart';

class BookProvider extends ChangeNotifier {
  Book? _currentBook;
  List<Book> _books = [];
  bool _isLoading = false;

  Book? get currentBook => _currentBook;
  int? get currentBookId => _currentBook?.id;
  List<Book> get books => _books;
  bool get isLoading => _isLoading;

  /// 加载指定账号下的所有账本
  Future<void> loadBooks(int accountId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _books = await BookService.instance.getBooksForAccount(accountId);
      final current = await BookService.instance.getCurrentBook();
      // 确保当前账本归属于这个账号，否则取第一个
      if (current != null && current.accountId == accountId) {
        _currentBook = current;
      } else {
        _currentBook = _books.isNotEmpty ? _books.first : null;
      }
    } catch (e) {
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 创建新账本（不自动切换，保持当前账本不变）
  Future<Book> createBook(int accountId, String name) async {
    final book = await BookService.instance.createBook(accountId, name);
    _books = await BookService.instance.getBooksForAccount(accountId);
    // 不切换，保持当前活跃账本
    final current = await BookService.instance.getCurrentBook();
    if (current != null && current.accountId == accountId) {
      _currentBook = current;
    }
    notifyListeners();
    return book;
  }

  /// 切换账本（同时切换数据库文件）
  Future<void> switchBook(int bookId) async {
    await BookService.instance.switchBook(bookId);
    // 切换到新账本的数据库文件
    await DBHelper.instance.setActiveBook(bookId);
    try {
      _currentBook = _books.firstWhere((b) => b.id == bookId);
    } catch (_) {
      _currentBook = null;
    }
    notifyListeners();
  }

  /// 切换账本并刷新列表
  Future<void> switchBookAndReload(int bookId) async {
    await switchBook(bookId);
  }

  /// 删除账本
  Future<void> deleteBook(int bookId, int accountId) async {
    await BookService.instance.deleteBook(bookId);
    _books = await BookService.instance.getBooksForAccount(accountId);
    final current = await BookService.instance.getCurrentBook();
    _currentBook = current;
    notifyListeners();
  }

  /// 重命名账本
  Future<void> renameBook(int bookId, String newName) async {
    await BookService.instance.renameBook(bookId, newName);
    _books = await BookService.instance.getBooksForAccount(_currentBook!.accountId);
    final current = await BookService.instance.getCurrentBook();
    _currentBook = current;
    notifyListeners();
  }

  /// 初始化当前活跃账本的数据库连接
  Future<void> initActiveBookDb() async {
    if (_currentBook == null) return;
    await DBHelper.instance.setActiveBook(_currentBook!.id);
  }
}
