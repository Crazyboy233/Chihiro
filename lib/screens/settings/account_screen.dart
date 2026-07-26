import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/account_provider.dart';
import '../../providers/book_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/habit_provider.dart';
import '../../utils/db_helper.dart';
import '../auth/login_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final currentAccount = accountProvider.currentAccount;
    final accounts = accountProvider.accounts;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '账号管理',
          style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 当前账号信息
          if (currentAccount != null) ...[
            _buildCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.person, size: 32, color: AppColors.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentAccount.username,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '当前登录 · 创建于 ${_formatDate(currentAccount.createdAt)}',
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '当前',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 所有账号列表
          const Text(
            '所有账号',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          _buildCard(
            child: Column(
              children: [
                ...accounts.asMap().entries.map((e) {
                  final isLast = e.key == accounts.length - 1;
                  final isCurrent = currentAccount != null && currentAccount.id == e.value.id;
                  return Column(
                    children: [
                      InkWell(
                        onTap: isCurrent ? null : () => _switchToAccount(e.value.id),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          child: Row(
                            children: [
                              Icon(
                                isCurrent ? Icons.check_circle : Icons.account_circle_outlined,
                                size: 22,
                                color: isCurrent ? AppColors.primary : Colors.grey,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  e.value.username,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              if (!isCurrent)
                                const Text(
                                  '点击切换',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (!isLast) const Divider(height: 1),
                    ],
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 操作按钮
          _buildCard(
            child: Column(
              children: [
                _buildListTile(
                  icon: Icons.person_add,
                  title: '添加新账号',
                  subtitle: '注册一个新账号',
                  onTap: _addAccount,
                ),
                if (currentAccount != null) ...[
                  const Divider(height: 1),
                  _buildListTile(
                    icon: Icons.lock_reset,
                    title: '修改密码',
                    subtitle: '修改当前账号的密码',
                    onTap: _changePassword,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Center(
            child: Text(
              '本地账号 · 数据保存在本地 · 不涉及联网',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _switchToAccount(int accountId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('切换账号'),
        content: const Text('切换后将加载该账号下的数据。确定切换吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('切换')),
        ],
      ),
    );
    if (confirmed != true) return;

    final accountProvider = context.read<AccountProvider>();
    final bookProvider = context.read<BookProvider>();
    try {
      await accountProvider.switchAccount(accountId);
      if (mounted) await bookProvider.loadBooks(accountId);
      if (mounted && bookProvider.currentBook != null) {
        await bookProvider.switchBook(bookProvider.currentBook!.id);
      }
      // 初始化账号级数据库（日程、打卡）
      if (mounted) await DBHelper.instance.setActiveAccount(accountId);
      // 切换账号后必须重载所有数据 Provider，否则内存中仍是旧账号数据
      if (mounted) {
        await context.read<CategoryProvider>().loadCategories();
        await context.read<TransactionProvider>().loadTransactions();
        await context.read<HabitProvider>().loadGoals();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已切换账号'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('切换失败: $e')),
        );
      }
    }
  }

  Future<void> _addAccount() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (mounted) {
      final ap = context.read<AccountProvider>();
      await ap.refresh();
      if (ap.currentAccount != null) {
        final bp = context.read<BookProvider>();
        await bp.loadBooks(ap.currentAccount!.id);
        if (bp.currentBook != null) {
          await bp.switchBook(bp.currentBook!.id);
        }
        // 重载所有数据 Provider
        await context.read<CategoryProvider>().loadCategories();
        await context.read<TransactionProvider>().loadTransactions();
        await context.read<HabitProvider>().loadGoals();
      }
    }
  }

  Future<void> _changePassword() async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: '原密码', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: '新密码', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: '确认新密码', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认')),
        ],
      ),
    );

    if (confirmed != true) return;
    if (newCtrl.text != confirmCtrl.text) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('两次输入的新密码不一致')),
        );
      }
      return;
    }

    try {
      await context.read<AccountProvider>().changePassword(oldCtrl.text, newCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('密码修改成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${e}'.replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.black87),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 22),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
