import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/book_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';

class BookScreen extends StatefulWidget {
  const BookScreen({super.key});

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  @override
  Widget build(BuildContext context) {
    final bookProvider = context.watch<BookProvider>();
    final accountProvider = context.watch<AccountProvider>();
    final currentBook = bookProvider.currentBook;
    final books = bookProvider.books;
    final accountId = accountProvider.currentAccount?.id;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '账本管理',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 当前账本
          if (currentBook != null) ...[
            _buildCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.menu_book, size: 28, color: AppColors.primary),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentBook.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '当前使用中',
                                style: TextStyle(fontSize: 13, color: AppColors.ts(context)),
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _renameBook(currentBook),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('重命名'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 所有账本列表
          Text(
            '所有账本',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          _buildCard(
            child: Column(
              children: [
                ...books.asMap().entries.map((e) {
                  final isLast = e.key == books.length - 1;
                  final isCurrent = currentBook != null && currentBook.id == e.value.id;
                  return Column(
                    children: [
                      InkWell(
                        onTap: isCurrent ? null : () => _switchToBook(e.value.id),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          child: Row(
                            children: [
                              Icon(
                                isCurrent ? Icons.check_circle : Icons.menu_book_outlined,
                                size: 22,
                                color: isCurrent ? AppColors.primary : AppColors.ts(context),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  e.value.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              if (books.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  tooltip: '删除账本',
                                  onPressed: () => _deleteBook(e.value),
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

          // 新建账本
          _buildCard(
            child: _buildListTile(
              icon: Icons.add_circle_outline,
              title: '新建账本',
              subtitle: '创建一个新的独立账本',
              onTap: () => _createBook(accountId),
            ),
          ),

          const SizedBox(height: 24),
          Center(
            child: Text(
              '每个账本拥有独立的数据（记账、日程、打卡）\n可在账本间切换，数据互不影响',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.ts(context), height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createBook(int? accountId) async {
    if (accountId == null) return;
    final nameCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建账本'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '账本名称',
            hintText: '如：旅行记账、家庭开支...',
            border: OutlineInputBorder(),
          ),
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
      await bp.createBook(accountId, nameCtrl.text.trim());
      // 新账本的 DB 已在 BookProvider.createBook → BookService.createBook 中初始化
      await _reloadAllProviders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('账本「${nameCtrl.text.trim()}」已创建')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _switchToBook(int bookId) async {
    final bp = context.read<BookProvider>();
    try {
      await bp.switchBook(bookId);
      await _reloadAllProviders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已切换账本'), duration: Duration(seconds: 1)),
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

  Future<void> _deleteBook(dynamic book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除账本'),
        content: Text('确定要删除「${book.name}」吗？\n\n该账本下的所有数据将被永久删除，无法恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
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
      await _reloadAllProviders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「${book.name}」已删除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _renameBook(dynamic book) async {
    final nameCtrl = TextEditingController(text: book.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名账本'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已重命名')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  /// 账本切换后重载所有 Provider 的数据
  Future<void> _reloadAllProviders() async {
    if (!mounted) return;
    try {
      await context.read<CategoryProvider>().loadCategories();
      await context.read<TransactionProvider>().loadTransactions();
      // 日程和打卡按需加载，此处不强制刷新
    } catch (_) {}
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: AppColors.ts(context)),
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
            Icon(icon, size: 22, color: Theme.of(context).colorScheme.onSurface),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.ts(context))),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.ts(context), size: 22),
          ],
        ),
      ),
    );
  }
}
