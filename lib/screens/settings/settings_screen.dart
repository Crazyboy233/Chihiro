import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/account_provider.dart';
import '../../providers/book_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/habit_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/db_helper.dart';
import 'data_management_screen.dart';
import 'about_screen.dart';
import 'changelog_screen.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const String appVersion = '2.0.0';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ======================== 账号 ========================

  Future<void> _switchAccount(int accountId) async {
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

    final ap = context.read<AccountProvider>();
    final bp = context.read<BookProvider>();
    try {
      await ap.switchAccount(accountId);
      if (mounted) await bp.loadBooks(accountId);
      if (mounted && bp.currentBook != null) {
        await bp.switchBook(bp.currentBook!.id);
      }
      if (mounted) await DBHelper.instance.setActiveAccount(accountId);
      if (mounted) {
        await context.read<CategoryProvider>().loadCategories();
        await context.read<TransactionProvider>().loadTransactions();
        await context.read<HabitProvider>().loadGoals();
      }
      if (mounted) {
        setState(() {});
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
        await DBHelper.instance.setActiveAccount(ap.currentAccount!.id);
        await context.read<CategoryProvider>().loadCategories();
        await context.read<TransactionProvider>().loadTransactions();
        await context.read<HabitProvider>().loadGoals();
      }
    }
  }

  Future<void> _changeUsername() async {
    final ap = context.read<AccountProvider>();
    final ctrl = TextEditingController(text: ap.currentAccount?.username ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改用户名'),
        content: TextField(
          controller: ctrl, autofocus: true,
          decoration: const InputDecoration(labelText: '新用户名', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认')),
        ],
      ),
    );
    if (confirmed != true || ctrl.text.trim().isEmpty) return;

    try {
      await ap.changeUsername(ctrl.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('用户名已修改')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${e}'.replaceFirst('Exception: ', ''))),
        );
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
              controller: oldCtrl, obscureText: true,
              decoration: const InputDecoration(labelText: '原密码', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl, obscureText: true,
              decoration: const InputDecoration(labelText: '新密码', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl, obscureText: true,
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('两次输入的新密码不一致')));
      }
      return;
    }
    try {
      await context.read<AccountProvider>().changePassword(oldCtrl.text, newCtrl.text);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('密码修改成功')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${e}'.replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  // ======================== 账本 ========================

  Future<void> _switchBook(int bookId) async {
    final bp = context.read<BookProvider>();
    try {
      await bp.switchBook(bookId);
      await context.read<CategoryProvider>().loadCategories();
      await context.read<TransactionProvider>().loadTransactions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已切换账本'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('切换失败: $e')));
      }
    }
  }

  Future<void> _createBook() async {
    final ap = context.read<AccountProvider>();
    if (ap.currentAccount == null) return;

    final nameCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建账本'),
        content: TextField(
          controller: nameCtrl, autofocus: true,
          decoration: const InputDecoration(labelText: '账本名称', hintText: '如：旅行记账、家庭开支...', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('创建')),
        ],
      ),
    );
    if (confirmed != true || nameCtrl.text.trim().isEmpty) return;

    final bp = context.read<BookProvider>();
    try {
      await bp.createBook(ap.currentAccount!.id, nameCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('账本「${nameCtrl.text.trim()}」已创建')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _deleteBook(dynamic book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除账本'),
        content: Text('确定要删除「${book.name}」吗？\n\n该账本下的所有数据将被永久删除，无法恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    final ap = context.read<AccountProvider>();
    final bp = context.read<BookProvider>();
    try {
      await bp.deleteBook(book.id, ap.currentAccount!.id);
      if (bp.currentBook != null) {
        await bp.switchBook(bp.currentBook!.id);
      }
      await context.read<CategoryProvider>().loadCategories();
      await context.read<TransactionProvider>().loadTransactions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('「${book.name}」已删除')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _renameBook(dynamic book) async {
    final nameCtrl = TextEditingController(text: book.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名账本'),
        content: TextField(
          controller: nameCtrl, autofocus: true,
          decoration: const InputDecoration(labelText: '新名称', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认')),
        ],
      ),
    );
    if (confirmed != true || nameCtrl.text.trim().isEmpty) return;

    final bp = context.read<BookProvider>();
    try {
      await bp.renameBook(book.id, nameCtrl.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已重命名')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  // ======================== 外观 ========================

  void _showThemeDialog(ThemeProvider themeProvider) {
    final cs = Theme.of(context).colorScheme;
    final currentMode = themeProvider.themeMode;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择主题模式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values.map((mode) {
            String label;
            IconData icon;
            switch (mode) {
              case ThemeMode.system:
                label = '跟随系统';
                icon = Icons.settings_suggest;
              case ThemeMode.light:
                label = '浅色模式';
                icon = Icons.light_mode;
              case ThemeMode.dark:
                label = '深色模式';
                icon = Icons.dark_mode;
            }
            return RadioListTile<ThemeMode>(
              value: mode,
              groupValue: currentMode,
              title: Row(
                children: [
                  Icon(icon, size: 20, color: cs.primary),
                  const SizedBox(width: 10),
                  Text(label),
                ],
              ),
              activeColor: cs.primary,
              onChanged: (v) {
                if (v != null) {
                  themeProvider.setThemeMode(v);
                  Navigator.pop(ctx);
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  // ======================== 构建 ========================

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final bookProvider = context.watch<BookProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final currentAccount = accountProvider.currentAccount;
    final currentBook = bookProvider.currentBook;
    final accounts = accountProvider.accounts;
    final books = bookProvider.books;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '我的',
          style: TextStyle(color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ============ 外观 ============
          _buildSectionTitle('🎨 外观'),
          const SizedBox(height: 8),
          _buildCard(
            child: _buildThemeTile(themeProvider),
          ),
          const SizedBox(height: 20),

          // ============ 账号区 ============
          _buildSectionTitle('👤 账号'),
          const SizedBox(height: 8),
          _buildCard(
            child: Column(
              children: [
                // 当前账号
                if (currentAccount != null) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.person, size: 26, color: cs.primary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(currentAccount.username,
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface)),
                              const SizedBox(height: 2),
                              Text('当前登录',
                                  style: TextStyle(fontSize: 12, color: AppColors.ts(context))),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('当前', style: TextStyle(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  _buildSubTile(Icons.edit, '修改用户名', _changeUsername),
                  _buildSubTile(Icons.lock_outline, '修改密码', _changePassword),
                ],
                // 账号列表
                if (accounts.length > 1) ...[
                  Divider(height: 1, indent: 16, color: AppColors.dv(context)),
                  ...accounts.where((a) => currentAccount == null || a.id != currentAccount.id).map((a) =>
                    _buildSubTileWithAction(
                      Icons.account_circle_outlined, a.username,
                      onTap: () => _switchAccount(a.id),
                      actionLabel: '切换',
                    ),
                  ),
                ],
                Divider(height: 1, indent: 16, color: AppColors.dv(context)),
                _buildSubTile(Icons.person_add, '添加新账号', _addAccount),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ============ 账本区 ============
          _buildSectionTitle('📒 当前账本'),
          const SizedBox(height: 8),
          _buildCard(
            child: Column(
              children: [
                // 当前账本
                if (currentBook != null) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: cs.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.menu_book, size: 26, color: cs.secondary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(currentBook.name,
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface)),
                              const SizedBox(height: 2),
                              Text('当前使用中',
                                  style: TextStyle(fontSize: 12, color: AppColors.ts(context))),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _renameBook(currentBook),
                          icon: Icon(Icons.edit, size: 16, color: cs.primary),
                          label: Text('重命名', style: TextStyle(fontSize: 13, color: cs.primary)),
                        ),
                      ],
                    ),
                  ),
                ],
                // 其他账本
                if (books.where((b) => currentBook == null || b.id != currentBook.id).isNotEmpty) ...[
                  Divider(height: 1, indent: 16, color: AppColors.dv(context)),
                  ...books.where((b) => currentBook == null || b.id != currentBook.id).map((b) =>
                    _buildSubTileWithActions(
                      Icons.menu_book_outlined, b.name,
                      onTap: () => _switchBook(b.id),
                      actionLabel: '切换',
                      onDelete: () => _deleteBook(b),
                    ),
                  ),
                ],
                Divider(height: 1, indent: 16, color: AppColors.dv(context)),
                _buildSubTile(Icons.add_circle_outline, '新建账本', _createBook),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ============ 其他 ============
          _buildSectionTitle('⚙️ 其他'),
          const SizedBox(height: 8),
          _buildCard(
            child: Column(
              children: [
                _buildListTile(Icons.folder, '数据管理', '导出、导入、备份文件管理', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DataManagementScreen()));
                }),
                Divider(height: 1, indent: 48, color: AppColors.dv(context)),
                _buildListTile(Icons.article_outlined, '更新说明', '查看各版本的功能更新', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangelogScreen()));
                }),
                Divider(height: 1, indent: 48, color: AppColors.dv(context)),
                _buildListTile(Icons.info_outline, '说明', '联网情况、数据收集与安全说明', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
                }),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Column(
              children: [
                Text('Chihiro v${SettingsScreen.appVersion}',
                    style: TextStyle(fontSize: 12, color: AppColors.ts(context))),
                const SizedBox(height: 4),
                Text(
                  currentAccount != null
                      ? '本地数据 · ${currentAccount.username}'
                      : '本地数据',
                  style: TextStyle(fontSize: 11, color: AppColors.ts(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ======================== 组件 ========================

  Widget _buildSectionTitle(String title) {
    final cs = Theme.of(context).colorScheme;
    return Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: cs.onSurface));
  }

  Widget _buildCard({required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: AppColors.bd(context)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _buildThemeTile(ThemeProvider themeProvider) {
    final cs = Theme.of(context).colorScheme;
    IconData icon;
    String subtitle;
    switch (themeProvider.themeMode) {
      case ThemeMode.dark:
        icon = Icons.dark_mode;
        subtitle = '深色模式';
      case ThemeMode.light:
        icon = Icons.light_mode;
        subtitle = '浅色模式';
      case ThemeMode.system:
        icon = Icons.settings_suggest;
        subtitle = '跟随系统';
    }

    return InkWell(
      onTap: () => _showThemeDialog(themeProvider),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('主题模式', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: cs.onSurface)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.ts(context))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: cs.onSurface),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: cs.onSurface)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.ts(context))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTile(IconData icon, String title, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: cs.onSurface),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(fontSize: 14, color: cs.onSurface))),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTileWithAction(IconData icon, String title,
      {required VoidCallback onTap, required String actionLabel}) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.ts(context)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(fontSize: 14, color: cs.onSurface))),
            Text(actionLabel, style: TextStyle(fontSize: 12, color: cs.primary)),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTileWithActions(IconData icon, String title,
      {required VoidCallback onTap, required String actionLabel, required VoidCallback onDelete}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.ts(context)),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(title, style: TextStyle(fontSize: 14, color: cs.onSurface))),
                    Text(actionLabel, style: TextStyle(fontSize: 12, color: cs.primary)),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}
