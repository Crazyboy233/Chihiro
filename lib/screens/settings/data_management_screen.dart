import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../utils/data_backup.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/habit_provider.dart';

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
    if (mounted) {
      setState(() {
        _backupPath = path;
      });
    }
  }

  // ============================================================
  // 导出数据
  // ============================================================
  Future<void> _doExport() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认导出'),
        content: const Text('将当前所有数据（记账、日程、打卡）导出为 JSON 文件'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('导出'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final path = await DataBackup.exportAll();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('✅ 导出成功！文件路径:\n$path'), duration: const Duration(seconds: 6)),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('❌ 导出失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // 手动输入路径导入
  // ============================================================
  Future<void> _doImportFromPath() async {
    final messenger = ScaffoldMessenger.of(context);
    final txProvider = context.read<TransactionProvider>();
    final habitProvider = context.read<HabitProvider>();
    // 先拿到当前备份目录，作为对话框默认值
    final defaultDir = _backupPath ?? await DataBackup.getBackupDirectoryPath();
    // 默认填入目录 + 示例文件名，用户只需修改文件名即可
    final controller = TextEditingController(
      text: '$defaultDir/chihiro_backup_yyyy-mm-dd.json',
    );
    if (!mounted) return;
    final selected = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入数据'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '提示：导入为「追加合并」模式，不会删除当前任何数据,如果已经一份数据，将会出现重复记录，请谨慎操作',
              style: TextStyle(color: Colors.green, fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              '下方已自动填入备份目录，请将文件名替换为你要导入的文件（例如 chihiro_backup_2026-06-14T10-30-00.json）',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: '文件完整路径',
              ),
              minLines: 2,
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('导入'),
          ),
        ],
      ),
    );

    if (selected == null || selected.isEmpty) return;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认导入'),
        content: const Text('将以「追加合并」模式导入文件中的数据，不会删除你当前已有的任何数据。确定继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('开始导入'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final result = await DataBackup.importFromFile(selected);
      await txProvider.loadTransactions();
      if (mounted) await habitProvider.loadGoals();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '✅ 导入成功！新增 ${result['inserted']} 条记录，合并复用 ${result['merged']} 条',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('❌ 导入失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // 从备份目录中选择文件导入
  // ============================================================
  Future<void> _showBackupListAndImport() async {
    final messenger = ScaffoldMessenger.of(context);
    final txProvider = context.read<TransactionProvider>();
    final habitProvider = context.read<HabitProvider>();
    final files = await DataBackup.listBackupFiles();
    if (files.isEmpty) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('当前目录下没有备份文件')),
        );
      }
      return;
    }

    if (!mounted) return;

    final selected = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择要导入的备份文件'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              final stat = file.statSync();
              return ListTile(
                title: Text(file.path.split('/').last),
                subtitle: Text('大小: ${(stat.size / 1024).toStringAsFixed(2)} KB'),
                onTap: () => Navigator.pop(context, file.path),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.grey),
                  onPressed: () async {
                    await DataBackup.deleteBackupFile(file.path);
                    if (mounted) Navigator.pop(this.context);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('取消'),
          ),
        ],
      ),
    );

    if (selected == null) return;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认导入'),
        content: const Text('将以「追加合并」模式导入文件中的数据，不会删除你当前已有的任何数据。确定继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('开始导入'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final result = await DataBackup.importFromFile(selected);
      await txProvider.loadTransactions();
      if (mounted) await habitProvider.loadGoals();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '✅ 导入成功！新增 ${result['inserted']} 条记录，合并复用 ${result['merged']} 条',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('❌ 导入失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          '数据管理',
          style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('正在处理，请稍候...'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // =============== 数据操作区 ===============
                _buildSectionTitle('📦 数据操作'),
                const SizedBox(height: 8),
                _buildCard(
                  child: Column(
                    children: [
                      _buildListTile(
                        icon: Icons.file_upload,
                        title: '导出数据',
                        subtitle: '把所有数据导出成 JSON 文件',
                        onTap: _doExport,
                      ),
                      const Divider(height: 1),
                      _buildListTile(
                        icon: Icons.file_download,
                        title: '从备份文件导入',
                        subtitle: '选择一个备份文件恢复数据',
                        onTap: _showBackupListAndImport,
                      ),
                      const Divider(height: 1),
                      _buildListTile(
                        icon: Icons.edit_note,
                        title: '手动输入路径导入',
                        subtitle: '已知文件路径时使用',
                        onTap: _doImportFromPath,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // =============== 备份目录说明 ===============
                _buildSectionTitle('📁 备份文件位置'),
                const SizedBox(height: 8),
                _buildCard(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '手机上备份文件保存在此目录，用文件管理器按路径逐层打开即可找到：',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _backupPath ?? '/storage/emulated/0/Android/data/com.chihiro/files/Backup',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.copy, color: Colors.black87, size: 20),
                                tooltip: '复制路径',
                                onPressed: () async {
                                  final scaffoldMessenger = ScaffoldMessenger.of(this.context);
                                  final path = _backupPath ?? await DataBackup.getBackupDirectoryPath();
                                  await Clipboard.setData(ClipboardData(text: path));
                                  if (mounted) {
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(content: Text('✅ 路径已复制'), duration: Duration(seconds: 2)),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '💡 小提示：导出的文件名类似 chihiro_backup_2026-06-14T10-30-00.json。重装后把文件复制到上面目录，再点"从备份文件导入"。',
                            style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Chihiro · 本地数据 · 你的数据只属于你',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
    );
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
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 22),
          ],
        ),
      ),
    );
  }
}
