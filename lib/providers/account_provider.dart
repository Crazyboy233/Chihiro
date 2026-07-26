import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../services/auth_service.dart';

class AccountProvider extends ChangeNotifier {
  Account? _currentAccount;
  List<Account> _accounts = [];
  bool _isLoading = false;
  bool _needsLogin = true;

  Account? get currentAccount => _currentAccount;
  List<Account> get accounts => _accounts;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentAccount != null;
  bool get needsLogin => _needsLogin;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      _accounts = await AuthService.instance.getAccounts();

      if (_accounts.isEmpty) {
        // 全新安装或所有账号已删除 → 需要注册/登录
        _needsLogin = true;
        _currentAccount = null;
      } else {
        final current = await AuthService.instance.getCurrentAccount();
        if (current != null) {
          _currentAccount = current;
          _needsLogin = false;
        } else {
          // 有账号但没有选中任何一个→ 需要登录
          _needsLogin = true;
        }
      }
    } catch (e) {
      _needsLogin = true;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 注册（不自动登录，注册后需手动登录）
  Future<void> register(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      await AuthService.instance.register(username, password);
      _accounts = await AuthService.instance.getAccounts();
      // 注册后不自动登录，保持当前登录状态
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 登录
  Future<void> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentAccount = await AuthService.instance.login(username, password);
      _accounts = await AuthService.instance.getAccounts();
      _needsLogin = false;
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 切换账号
  Future<void> switchAccount(int accountId) async {
    await AuthService.instance.switchAccount(accountId);
    _accounts = await AuthService.instance.getAccounts();
    try {
      _currentAccount = _accounts.firstWhere((a) => a.id == accountId);
    } catch (_) {
      _currentAccount = null;
    }
    _needsLogin = _currentAccount == null;
    notifyListeners();
  }

  /// 退出登录
  Future<void> logout() async {
    await AuthService.instance.logout();
    _currentAccount = null;
    _accounts = [];
    _needsLogin = true;
    notifyListeners();
  }

  /// 删除账号
  Future<void> deleteAccount(int accountId) async {
    await AuthService.instance.deleteAccount(accountId);
    _accounts = await AuthService.instance.getAccounts();
    if (_currentAccount != null && _currentAccount!.id == accountId) {
      _currentAccount = _accounts.isNotEmpty ? _accounts.first : null;
      if (_currentAccount != null) {
        await AuthService.instance.switchAccount(_currentAccount!.id);
      }
    }
    _needsLogin = _currentAccount == null;
    notifyListeners();
  }

  /// 修改密码
  Future<void> changePassword(String oldPassword, String newPassword) async {
    if (_currentAccount == null) throw Exception('未登录');
    await AuthService.instance.changePassword(
        _currentAccount!.id, oldPassword, newPassword);
  }

  /// 修改用户名
  Future<void> changeUsername(String newUsername) async {
    if (_currentAccount == null) throw Exception('未登录');
    await AuthService.instance.changeUsername(_currentAccount!.id, newUsername);
    _accounts = await AuthService.instance.getAccounts();
    _currentAccount = _accounts.firstWhere((a) => a.id == _currentAccount!.id);
    notifyListeners();
  }

  /// 刷新列表（用于从其他页面返回时）
  Future<void> refresh() async {
    _accounts = await AuthService.instance.getAccounts();
    final current = await AuthService.instance.getCurrentAccount();
    _currentAccount = current;
    _needsLogin = _currentAccount == null;
    notifyListeners();
  }
}
