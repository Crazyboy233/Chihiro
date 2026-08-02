import 'package:flutter/material.dart';
import '../../constants/colors.dart';

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

// 在这里��加新版本的更新说明
const List<ChangelogEntry> changelog = [
  ChangelogEntry(
    version: 'V2.1.0',
    date: '2026-08-02',
    newFeatures: [
      '新增暗色模式：「我的」页面可切换浅色 / 深色模式 / 跟随系统',
      '新增搜索功能：首页顶部可按分类名称、分类备注、备注关键字搜索账单',
      '新增倒数日：日程页顶部「倒数日」页签，支持「倒数」（还有 N 天）和「正数」（已坚持 N 天）两种，到期当天整卡高亮，并自动预置国内法定节假日',
      '新增打卡热力图：打卡页「热力图」视图，全年一屏总览，下方按目标拆分，含打卡天数、累计次数、连续天数统计',
    ],
  ),
  ChangelogEntry(
    version: 'V2.0.0',
    date: '2026-07-26',
    newFeatures: [
      '新增账号系统：可注册多个本地账号，每个账号拥有独立的数据',
      '新增多账本功能：每个账号可创建多个独立账本，数据完全隔离',
      '支持账本级备份和账号级备份，导入时自动识别备份类型',
      '「我的」页面新增账号管理和账本管理入口，支持切换、新建、删除',
      '新增分类：买药、医院',
      '注：由于所有数据保存在本地，忘记密码可以使用万能密码 chihiro 登录',
    ],
  ),
  ChangelogEntry(
    version: 'V1.2.1',
    date: '2026-07-26',
    bugFixes: [
      '修复统计页饼图分类过多时标签相互覆盖的问题：引线改为斜线直连、标签按上下半区分组摆放，扇形指向一目了然',
    ],
  ),
  ChangelogEntry(
    version: 'V1.2.0',
    date: '2026-07-10',
    newFeatures: [
      '统计页新增饼图，点击右上角图表按钮可查看各分类支出占比，支持点击扇区放大、引线标注',
      '日程支持跨天安排，可设置从某天到某天的长时间日程，日历中以彩色横条跨单元格显示',
    ],
    bugFixes: [
      '修复日程单元格文字溢出到相邻单元格的问题',
    ],
  ),
  ChangelogEntry(
    version: 'V1.1.4',
    date: '2026-06-23',
    newFeatures: [
      '首页账单按日期分组，分组右侧显示当日支出总计',
    ],
    optimizations: [
      '统计页和日程页左右滑动切换加入平滑过渡动画，与打卡页日历翻页效果一致',
    ],
  ),
  ChangelogEntry(
    version: 'V1.1.3',
    date: '2026-06-17',
    newFeatures: [
      '新增分类：酒店、出去浪',
    ],
    optimizations: [
      '日程日历支持左滑/右滑屏幕切换月份',
      '统计界面支持左滑/右滑切换周/月/年',
      '统计界面的详细分类的每笔账单现在会显示分类备注 + 个人备注',
    ],
  ),
  ChangelogEntry(
    version: 'V1.1.2',
    date: '2026-06-15',
    optimizations: [
      '新增部分分类，分类改为内嵌式，可单独下滑以查看所有分类',
      '支持拖动分类图标交换分类位置',
    ],
    bugFixes: [
      '修复打卡完成后颜色固定为绿色的 bug，现在会正确显示目标所选颜色',
    ],
  ),
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
      appBar: AppBar(
        elevation: 0,
        title: Text(
          '更新说明',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: changelog.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final entry = changelog[index];
          return _buildVersionCard(context, entry);
        },
      ),
    );
  }

  Widget _buildVersionCard(BuildContext context, ChangelogEntry entry) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: AppColors.ts(context)),
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                entry.date,
                style: TextStyle(fontSize: 12, color: AppColors.ts(context)),
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
            ...entry.newFeatures.map((item) => _buildItem(context, item)),
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
            ...entry.optimizations.map((item) => _buildItem(context, item)),
          ],

          // 修复bug
          if (entry.bugFixes.isNotEmpty) ...[
            const SizedBox(height: 6),
            const _SectionHeader(
              label: '🐛 修复bug',
              color: Color(0xFFEF4444),
            ),
            const SizedBox(height: 8),
            ...entry.bugFixes.map((item) => _buildItem(context, item)),
          ],
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, String text) {
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
              decoration: BoxDecoration(
                color: AppColors.ts(context),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurface,
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
