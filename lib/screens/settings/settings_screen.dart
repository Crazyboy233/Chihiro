import 'package:flutter/material.dart';
import 'data_management_screen.dart';
import 'about_screen.dart';
import 'changelog_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // 软件版本号 — 每次发版时这里和 pubspec.yaml / build.gradle / Info.plist 同步更新
  static const String appVersion = '1.1.0';
  static const int appBuild = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '我的',
          style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // =============== 数据管理入口 ===============
          _buildCard(
            child: Column(
              children: [
                _buildListTile(
                  icon: Icons.folder,
                  title: '数据管理',
                  subtitle: '导出、导入、备份文件管理',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DataManagementScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, thickness: 1, indent: 48),
                _buildListTile(
                  icon: Icons.article_outlined,
                  title: '更新说明',
                  subtitle: '查看各版本的功能更新',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChangelogScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, thickness: 1, indent: 48),
                _buildListTile(
                  icon: Icons.info_outline,
                  title: '说明',
                  subtitle: '联网情况、数据收集与安全说明',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AboutScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Center(
            child: Column(
              children: [
                Text(
                  'Chihiro v$appVersion',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                SizedBox(height: 4),
                Text(
                  '本地数据 · 你的数据只属于你',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
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
