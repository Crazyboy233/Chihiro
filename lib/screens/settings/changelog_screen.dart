import 'package:flutter/material.dart';

// ============== 版本更新说明数据 ==============
class ChangelogEntry {
  final String version;
  final String date;
  final List<String> newFeatures;
  final List<String> optimizations;
  final List<String> bugFixes;

  const ChangelogEntry({
    required this.version,
    required this.date,
    this.newFeatures = const [],
    this.optimizations = const [],
    this.bugFixes = const [],
  });
}

// 在这里添加新版本的更新说明
const List<ChangelogEntry> changelog = [
  ChangelogEntry(
    version: 'V1.1.1',
    date: '2026-06-14',
    optimizations: [
      '优化数据导入导出功能，支持通过系统文件管理器选择文件导入',
      '更改了导出数据的保存路径（改为 Download/ChihiroBackup，文件管理器直接可见）',
    ],
    bugFixes: [
      '修复打卡记录在各种交互场景下被清空或丢失的问题',
    ],
  ),
  ChangelogEntry(
    version: 'V1.1',
    date: '2026-06-14',
    newFeatures: [
      '可以对已有打卡目标进行编辑',
      '打卡目标可设置截止日期',
      '可以对已有日程事件进行编辑',
      '统计界面每个分类支持点开，可以查看该分类的每笔记录以及时间',
    ],
    optimizations: [
      '优化首页频繁切换周/月/年导致闪屏的问题',
      '优化数据导入功能，手动输入路径时会默认填充一部分路径',
      '导入数据现在是以追加形式写入的，而不是清空当前数据再写入',
      '首页上方的「千寻」替换为「Chihiro」',
      '统计界面 UI 优化',
    ],
  ),
  ChangelogEntry(
    version: 'V1.0',
    date: '2026-06-14',
    newFeatures: [
      '基础记账功能：收入、支出、分类',
      '打卡目标：创建、打卡、查看进度',
      '日程管理：添加、查看日程事件',
      '数据统计：按时间维度查看支出/收入统计',
      '数据备份与导入：导出 JSON、从备份文件导入',
    ],
    optimizations: [],
  ),
];

// ============== 版本更新说明页面 ==============
class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '更新说明',
          style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: changelog.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final entry = changelog[index];
          return _buildVersionCard(entry);
        },
      ),
    );
  }

  Widget _buildVersionCard(ChangelogEntry entry) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 版本名 + 日期
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                entry.version,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                entry.date,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 新增功能
          if (entry.newFeatures.isNotEmpty) ...[
            const _SectionHeader(
              label: '✨ 新增功能',
              color: Color(0xFF6366F1),
            ),
            const SizedBox(height: 8),
            ...entry.newFeatures.map((item) => _buildItem(item)),
            const SizedBox(height: 4),
          ],

          // 优化
          if (entry.optimizations.isNotEmpty) ...[
            const SizedBox(height: 6),
            const _SectionHeader(
              label: '🔧 优化',
              color: Color(0xFF10B981),
            ),
            const SizedBox(height: 8),
            ...entry.optimizations.map((item) => _buildItem(item)),
          ],

          // 修复bug
          if (entry.bugFixes.isNotEmpty) ...[
            const SizedBox(height: 6),
            const _SectionHeader(
              label: '🐛 修复bug',
              color: Color(0xFFEF4444),
            ),
            const SizedBox(height: 8),
            ...entry.bugFixes.map((item) => _buildItem(item)),
          ],
        ],
      ),
    );
  }

  Widget _buildItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 小节标题（✨ 新增功能 / 🔧 优化）
class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;

  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
