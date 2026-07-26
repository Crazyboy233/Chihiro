import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../utils/data_backup.dart';
import '../../providers/account_provider.dart';
import '../../providers/book_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/habit_provider.dart';
import '../../providers/category_provider.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key});

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  String? _backupPath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBackupPath();
  }

  Future<void> _loadBackupPath() async {
    final path = await DataBackup.getBackupDirectoryPath();
    if (mounted) setState(() => _backupPath = path);
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 5)),
    );
  }

  // ========== 导出当前账本 ==========
  Future<void> _exportBook() async {
    final bp = context.read<BookProvider>();
    final currentBook = bp.currentBook;
    if (currentBook == null) { _showMsg('没有活跃账本'); return; }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导出当前账本'),
        content: Text('将「${currentBook.name}」的数据导出为 JSON 文件。\n\n文件将保存在 Download/ChihiroBackup 目录。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('导出')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final path = await DataBackup.exportBook(currentBook.id, currentBook.name);
      if (mounted) _showMsg('✅ 导出成功！\n$path');
      await _loadBackupPath();
    } catch (e) {
      if (mounted) _showMsg('❌ 导出失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ========== 导出整个账号 ==========
  Future<void> _exportAccount() async {
    final ap = context.read<AccountProvider>();
    final bp = context.read<BookProvider>();
    final account = ap.currentAccount;
    if (account == null) { _showMsg('未登录'); return; }

    final books = bp.books;
    if (books.isEmpty) { _showMsg('当前账号下没有账本'); return; }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导出整个账号'),
        content: Text('将账号「${account.username}」下 ${books.length} 个账本的全部数据导出为一个 JSON 文件。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('导出')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final bookMetas = books.map((b) => {'id': b.id, 'name': b.name}).toList();
      final path = await DataBackup.exportAccount(
        accountName: account.username, accountId: account.id, bookMetas: bookMetas,
      );
      if (mounted) _showMsg('✅ 导出成功！\n$path');
      await _loadBackupPath();
    } catch (e) {
      if (mounted) _showMsg('❌ 导出失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ========== 共享导入检查（同名账本阻止） ==========
  Future<void> _checkAndImport(String filePath) async {
    final bp = context.read<BookProvider>();
    final ap = context.read<AccountProvider>();

    final backupType = await DataBackup.detectBackupType(filePath);
    final backupName = await DataBackup.getBackupBookName(filePath);

    // 同名账本：阻止导入
    if (backupType == 'book' && backupName != null && backupName == bp.currentBook?.name) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('无法导入'),
          content: Text('备份文件来自当前账本「$backupName」。\n\n直接导入会导致账单重复，无法执行。\n\n请先新建一个空账本，切换过去后再导入。'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('我知道了'))],
        ),
      );
      return;
    }

    // 确认对话框
    String title;
    String confirmMsg;
    if (backupType == 'account') {
      title = '账号级备份导入';
      confirmMsg = '这是一个整个账号的备份文件。\n\n将为每个账本创建独立账本并导入数据。\n当前账号已有 ${bp.books.length} 个账本。\n\n📄 $filePath';
    } else if (backupType == 'book') {
      title = '账本级备份导入';
      confirmMsg = '将以「追加合并」模式导入到当前账本「${bp.currentBook!.name}」中。\n\n📄 $filePath';
    } else {
      title = '旧版备份导入';
      confirmMsg = '旧版备份（将导入到当前账本）。\n\n📄 $filePath';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(confirmMsg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('开始导入')),
        ],
      ),
    );
    if (confirmed != true) return;

    String result;
    if (backupType == 'account') {
      result = await DataBackup.importAccountBackup(
        filePath,
        currentAccountId: ap.currentAccount!.id,
        currentBookId: bp.currentBook!.id,
        createBook: (name) async {
          final book = await bp.createBook(ap.currentAccount!.id, name);
          return book.id;
        },
      );
    } else {
      result = await DataBackup.importFromFile(
        filePath,
        currentAccountId: ap.currentAccount!.id,
        currentBookId: bp.currentBook!.id,
        onBooksChanged: () async {},
      );
    }

    await context.read<CategoryProvider>().loadCategories();
    await context.read<TransactionProvider>().loadTransactions();
    if (mounted) await context.read<HabitProvider>().loadGoals();
    if (mounted) _showMsg('✅ 导入成功！\n$result');
  }

  // ========== 从手机选择文件导入 ==========
  Future<void> _doImportFromPicker() async {
    final ap = context.read<AccountProvider>();
    final bp = context.read<BookProvider>();
    if (ap.currentAccount == null || bp.currentBook == null) {
      _showMsg('请先登录并选择账本'); return;
    }

    setState(() => _isLoading = true);
    final selected = await DataBackup.pickBackupFile();
    if (mounted) setState(() => _isLoading = false);
    if (selected == null) return;

    setState(() => _isLoading = true);
    try {
      await _checkAndImport(selected);
      if (mounted) await _loadBackupPath();
    } catch (e) {
      if (mounted) _showMsg('❌ 导入失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ========== 从备份目录选择导入 ==========
  Future<void> _showBackupListAndImport() async {
    final files = await DataBackup.listBackupFiles();
    if (files.isEmpty) { _showMsg('当前目录下没有备份文件'); return; }

    if (!mounted) return;
    final selected = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择备份文件'),
        content: SizedBox(
          width: double.maxFinite, height: 300,
          child: ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              final stat = file.statSync();
              return ListTile(
                title: Text(file.path.split('/').last, style: const TextStyle(fontSize: 13)),
                subtitle: Text('${(stat.size / 1024).toStringAsFixed(1)} KB'),
                onTap: () => Navigator.pop(ctx, file.path),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.grey, size: 20),
                  onPressed: () async {
                    await DataBackup.deleteBackupFile(file.path);
                    if (mounted) Navigator.pop(ctx, null);
                    setState(() {});
                  },
                ),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('取消'))],
      ),
    );
    if (selected == null) return;

    setState(() => _isLoading = true);
    try {
      await _checkAndImport(selected);
      if (mounted) await _loadBackupPath();
    } catch (e) {
      if (mounted) _showMsg('❌ 导入失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ========== 手动输入路径导入 ==========
  Future<void> _doImportFromPath() async {
    final defaultDir = _backupPath ?? await DataBackup.getBackupDirectoryPath();
    final controller = TextEditingController(text: '$defaultDir/chihiro_backup_yyyy-mm-dd.json');
    if (!mounted) return;
    final selected = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('手动输入路径'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('提示：导入为「追加合并」模式，不会删除当前任何数据。',
                style: TextStyle(color: Colors.green, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '文件完整路径'),
              minLines: 2, maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('导入')),
        ],
      ),
    );
    if (selected == null || selected.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _checkAndImport(selected);
      if (mounted) await _loadBackupPath();
    } catch (e) {
      if (mounted) _showMsg('❌ 导入失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BookProvider>();
    final ap = context.watch<AccountProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('数据管理', style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 12), Text('正在处理，请稍候...')]))
          : ListView(padding: const EdgeInsets.all(16), children: [
              _buildSectionTitle('📦 导出'), const SizedBox(height: 8),
              _buildCard(child: Column(children: [
                _buildListTile(Icons.file_upload, '导出当前账本',
                    bp.currentBook != null ? '导出「${bp.currentBook!.name}」的数据' : '导出当前账本数据', _exportBook),
                const Divider(height: 1),
                _buildListTile(Icons.cloud_upload, '导出整个账号',
                    ap.currentAccount != null ? '导出「${ap.currentAccount!.username}」下全部 ${bp.books.length} 个账本' : '导出所有账本数据', _exportAccount),
              ])),
              const SizedBox(height: 16),
              _buildSectionTitle('📥 导入'), const SizedBox(height: 8),
              _buildCard(child: Column(children: [
                _buildListTile(Icons.folder_open, '从手机选择文件导入', '自动识别账本/账号备份（推荐）', _doImportFromPicker, highlight: true),
                const Divider(height: 1),
                _buildListTile(Icons.file_download, '从备份目录选择', '扫描当前备份目录下的文件', _showBackupListAndImport),
                const Divider(height: 1),
                _buildListTile(Icons.edit_note, '手动输入路径导入', '已知文件完整路径时使用', _doImportFromPath),
              ])),
              const SizedBox(height: 16),
              _buildSectionTitle('📁 备份文件位置'), const SizedBox(height: 8),
              _buildCard(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('文件保存在公共 Download 目录下，在文件管理器中直接可见：', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)),
                  child: Row(children: [
                    Expanded(child: Text(_backupPath ?? '/storage/emulated/0/Download/ChihiroBackup', style: const TextStyle(fontSize: 13, fontFamily: 'monospace'))),
                    IconButton(icon: const Icon(Icons.copy, color: Colors.black87, size: 20), onPressed: () async {
                      final path = _backupPath ?? await DataBackup.getBackupDirectoryPath();
                      await Clipboard.setData(ClipboardData(text: path));
                      if (mounted) _showMsg('✅ 路径已复制');
                    }),
                  ]),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('⚠️ ', style: TextStyle(fontSize: 13)),
                      Expanded(
                        child: Text(
                          '请勿修改导出文件的文件名，否则导入时将无法通过账本名判断是否为当前账本的备份。',
                          style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(8)),
                  child: const Text('💡 换机提示：在旧手机上导出备份 → 通过微信/QQ/蓝牙等把文件发送到新手机 → 新手机安装 Chihiro → 在新手机上点「从手机选择文件导入」即可。',
                      style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.5)),
                ),
              ]))),
              const SizedBox(height: 24),
            ]),
    );
  }

  Widget _buildSectionTitle(String t) => Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87));
  Widget _buildCard({required Widget child}) => Container(decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey[200]!), borderRadius: BorderRadius.circular(12)), child: child);

  Widget _buildListTile(IconData icon, String title, String subtitle, VoidCallback onTap, {bool highlight = false}) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: highlight ? BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12)) : null,
        child: Row(children: [
          Icon(icon, size: 22, color: highlight ? Colors.green[700] : Colors.black87),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: highlight ? Colors.green[700] : Colors.black87)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ])),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 22),
        ]),
      ),
    );
  }
}
