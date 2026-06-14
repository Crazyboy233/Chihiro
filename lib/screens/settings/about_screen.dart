import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
          '说明',
          style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // =============== 联网情况 ===============
          _buildSection(
            icon: Icons.wifi_find_outlined,
            title: '联网情况',
            children: const [
              _BulletPoint(text: '✅ 记账、日程、打卡等核心功能均不联网，数据保存在手机本地的 SQLite 数据库中。'),
              _BulletPoint(text: '✅ 数据备份功能（导出/导入）只读写手机本地存储上的 JSON 文件，不经过任何服务器。'),
              _BulletPoint(text: 'ℹ️ 软件仅会通过联网获取日历节假日信息，不会使用网络做其他任何事情。'),
            ],
          ),
          const SizedBox(height: 12),

          // =============== 数据收集情况 ===============
          _buildSection(
            icon: Icons.privacy_tip_outlined,
            title: '数据收集情况',
            children: const [
              _BulletPoint(text: '❌ 不收集任何个人信息。'),
              _BulletPoint(text: '❌ 不收集设备信息。'),
              _BulletPoint(text: '❌ 不收集使用统计数据。'),
              _BulletPoint(text: '❌ 不使用任何第三方统计、分析 SDK（如友盟、Google Analytics 等）。'),
            ],
          ),
          const SizedBox(height: 12),

          // =============== 数据安全 ===============
          _buildSection(
            icon: Icons.security,
            title: '数据安全',
            children: const [
              _BulletPoint(text: '🔒 你的数据只属于你，保存在你自己的设备上。'),
              _BulletPoint(text: '🔒 不会上传到任何云端服务器。'),
              _BulletPoint(text: '🔒 不会与其他应用共享。'),
              _BulletPoint(text: '🔒 如需保护数据安全，请在「我的 → 数据管理」中定期导出备份。'),
              _BulletPoint(text: '⚠️ 卸载应用或清除应用数据会导致数据丢失，请在操作前先导出备份。'),
            ],
          ),
          const SizedBox(height: 12),

          // =============== 权限说明 ===============
          _buildSection(
            icon: Icons.perm_device_information,
            title: '权限说明',
            children: const [
              _BulletPoint(text: '📱 本应用仅申请存储权限（用于导出/导入备份文件）。'),
              _BulletPoint(text: '📱 不申请定位、通讯录、相机、麦克风、通话记录等其他任何敏感权限。'),
            ],
          ),
          const SizedBox(height: 12),

          // =============== 版本与包名 ===============
          _buildSection(
            icon: Icons.verified_user_outlined,
            title: '应用信息',
            children: const [
              _BulletText(label: '版本', value: 'V1.1.1'),
              _BulletText(label: '应用名', value: 'Chihiro'),
              _BulletText(label: '包名', value: 'com.chihiro'),
              _BulletText(label: '数据类型', value: 'SQLite 本地数据库 + JSON 备份文件'),
            ],
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

  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.black87),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
      ),
    );
  }
}

class _BulletText extends StatelessWidget {
  final String label;
  final String value;
  const _BulletText({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
