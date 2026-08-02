import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/habit_goal.dart';
import '../../providers/habit_provider.dart';

/// 打卡热力图视图（GitHub 风格全年格子图）
///
/// - 主图：全年总览，整年 53 周一屏全展示（格子宽度自适应），
///   按当天目标完成率分 5 级绿色强度
/// - 下方：按目标拆分行，每个目标一张全年热力图（目标色）
/// - 预留年度报告扩展位（当前仅按年切换浏览）
class HabitHeatmapView extends StatefulWidget {
  const HabitHeatmapView({super.key});

  @override
  State<HabitHeatmapView> createState() => _HabitHeatmapViewState();
}

class _HabitHeatmapViewState extends State<HabitHeatmapView> {
  late int _year;

  /// 主图绿色强度（基于 AppColors.secondary）
  static const _green = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadYear());
  }

  Future<void> _loadYear() async {
    if (!mounted) return;
    final provider = context.read<HabitProvider>();
    await provider.loadAllRecordsForMonth(
      DateTime(_year, 1, 1),
      DateTime(_year, 12, 31),
    );
  }

  void _changeYear(int delta) {
    final currentYear = DateTime.now().year;
    final next = _year + delta;
    if (next < 2020 || next > currentYear) return;
    setState(() {
      _year = next;
    });
    _loadYear();
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// 生成全年周列：每列 7 天（周一在上），非本年的位置为 null
  List<List<DateTime?>> _buildYearColumns() {
    final jan1 = DateTime(_year, 1, 1);
    // 网格从 1 月 1 日所在周的周一开始
    final gridStart = jan1.subtract(Duration(days: jan1.weekday - 1));
    final dec31 = DateTime(_year, 12, 31);
    final totalDays = dec31.difference(gridStart).inDays + 1;
    final weeks = (totalDays + 6) ~/ 7;

    return List.generate(weeks, (w) {
      return List.generate(7, (r) {
        final date = gridStart.add(Duration(days: w * 7 + r));
        if (date.year != _year) return null;
        return date;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HabitProvider>(
      builder: (context, provider, _) {
        final columns = _buildYearColumns();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            _buildOverviewCard(provider, columns),
            const SizedBox(height: 12),
            if (provider.goals.isEmpty)
              _buildEmptyHint()
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: Text(
                  '按目标拆分',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ts(context),
                  ),
                ),
              ),
              ...provider.goals.map(
                (goal) => _buildGoalCard(provider, goal, columns),
              ),
            ],
          ],
        );
      },
    );
  }

  // ============ 全年总览 ============

  Widget _buildOverviewCard(
      HabitProvider provider, List<List<DateTime?>> columns) {
    final cs = Theme.of(context).colorScheme;
    final today = _today;

    // ---- 统计 ----
    int totalCheckins = 0;
    final activeDays = <DateTime>{};
    for (final col in columns) {
      for (final date in col) {
        if (date == null) continue;
        final count = provider.getCompletedGoalIdsForDate(date).length;
        if (count > 0) {
          totalCheckins += count;
          activeDays.add(date);
        }
      }
    }
    // 连续天数：今天还没打卡不算中断，从昨天往前数
    int streak = 0;
    if (_year <= today.year) {
      var cursor = _year < today.year ? DateTime(_year, 12, 31) : today;
      if (!activeDays.contains(cursor)) {
        cursor = cursor.subtract(const Duration(days: 1));
      }
      while (activeDays.contains(cursor)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题 + 年份切换
          Row(
            children: [
              Text(
                '全年总览',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              _buildYearSwitcher(),
            ],
          ),
          const SizedBox(height: 8),
          // 统计行
          Row(
            children: [
              _buildStatChip('${activeDays.length}', '打卡天数'),
              const SizedBox(width: 16),
              _buildStatChip('$totalCheckins', '累计次数'),
              const SizedBox(width: 16),
              _buildStatChip('$streak', '连续天数', highlight: streak > 0),
            ],
          ),
          const SizedBox(height: 14),
          // 热力图（整年一屏全展示）
          _FitYearHeatmap(
            columns: columns,
            showMonthLabels: true,
            today: today,
            colorFor: (date) => _overviewCellColor(provider, date),
          ),
          const SizedBox(height: 10),
          // 图例
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('少', style: TextStyle(fontSize: 10, color: AppColors.tt(context))),
              const SizedBox(width: 4),
              _legendCell(AppColors.dv(context)),
              _legendCell(_green.withValues(alpha: 0.25)),
              _legendCell(_green.withValues(alpha: 0.5)),
              _legendCell(_green.withValues(alpha: 0.75)),
              _legendCell(_green),
              const SizedBox(width: 4),
              Text('多', style: TextStyle(fontSize: 10, color: AppColors.tt(context))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYearSwitcher() {
    final currentYear = DateTime.now().year;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _yearArrow(Icons.chevron_left, _year > 2020 ? () => _changeYear(-1) : null),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '$_year',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        _yearArrow(
            Icons.chevron_right, _year < currentYear ? () => _changeYear(1) : null),
      ],
    );
  }

  Widget _yearArrow(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: onTap != null
              ? AppColors.dv(context)
              : AppColors.dv(context).withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap != null
              ? Theme.of(context).colorScheme.onSurface
              : AppColors.tt(context),
        ),
      ),
    );
  }

  Widget _buildStatChip(String value, String label, {bool highlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: highlight ? _green : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppColors.ts(context)),
        ),
      ],
    );
  }

  Widget _legendCell(Color color) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  /// 主图格子颜色：按当天目标完成率分 5 级
  Color _overviewCellColor(HabitProvider provider, DateTime date) {
    final today = _today;
    if (date.isAfter(today)) {
      return AppColors.dv(context).withValues(alpha: 0.35);
    }
    final dueGoals =
        provider.goals.where((g) => provider.shouldShowOnDate(g, date)).toList();
    if (dueGoals.isEmpty) return AppColors.dv(context);

    final done = dueGoals
        .where((g) => g.id != null && provider.isCompleted(g.id!, date))
        .length;
    if (done == 0) return AppColors.dv(context);

    final rate = done / dueGoals.length;
    if (rate >= 1) return _green;
    if (rate >= 0.67) return _green.withValues(alpha: 0.75);
    if (rate >= 0.34) return _green.withValues(alpha: 0.5);
    return _green.withValues(alpha: 0.25);
  }

  // ============ 按目标拆分 ============

  Widget _buildGoalCard(
    HabitProvider provider,
    HabitGoal goal,
    List<List<DateTime?>> columns,
  ) {
    final cs = Theme.of(context).colorScheme;
    final goalColor =
        Color(int.parse('0xFF${goal.color.replaceFirst('#', '')}'));
    final today = _today;

    // 统计：今年（截至今天）该目标应打卡天数与完成天数
    int dueDays = 0;
    int doneDays = 0;
    for (final col in columns) {
      for (final date in col) {
        if (date == null || date.isAfter(today)) continue;
        if (provider.shouldShowOnDate(goal, date)) {
          dueDays++;
          if (goal.id != null && provider.isCompleted(goal.id!, date)) {
            doneDays++;
          }
        }
      }
    }
    final rate = dueDays > 0 ? (doneDays / dueDays * 100).toStringAsFixed(0) : '0';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: goalColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(goal.icon, style: const TextStyle(fontSize: 15)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  goal.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$doneDays 次',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: goalColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '完成率 $rate%',
                style: TextStyle(fontSize: 11, color: AppColors.ts(context)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _FitYearHeatmap(
            columns: columns,
            showMonthLabels: true,
            today: today,
            colorFor: (date) => _goalCellColor(provider, goal, date, goalColor),
          ),
        ],
      ),
    );
  }

  Color _goalCellColor(
    HabitProvider provider,
    HabitGoal goal,
    DateTime date,
    Color goalColor,
  ) {
    final today = _today;
    if (date.isAfter(today)) {
      return AppColors.dv(context).withValues(alpha: 0.35);
    }
    if (!provider.shouldShowOnDate(goal, date)) {
      return AppColors.dv(context).withValues(alpha: 0.5);
    }
    final done = goal.id != null && provider.isCompleted(goal.id!, date);
    return done ? goalColor : goalColor.withValues(alpha: 0.15);
  }

  Widget _buildEmptyHint() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          '还没有打卡目标，点击右下角 + 创建一个，\n热力图会记录你的每一次坚持',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.ts(context), height: 1.6),
        ),
      ),
    );
  }
}

/// 整年一屏全展示的热力图网格
///
/// 格子宽度根据可用空间自适应（全年 53 周完整可见，无需滚动），
/// 宽屏（平板/桌面）下格子不超过 11px 并整体居中。
class _FitYearHeatmap extends StatelessWidget {
  final List<List<DateTime?>> columns;
  final bool showMonthLabels;
  final DateTime today;
  final Color? Function(DateTime date) colorFor;

  static const double _gap = 1.5;
  static const double _maxCell = 11.0;

  const _FitYearHeatmap({
    required this.columns,
    required this.showMonthLabels,
    required this.today,
    required this.colorFor,
  });

  @override
  Widget build(BuildContext context) {
    final weeks = columns.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 自适应格子宽度：整年完整放入可用宽度
        // 下限 1.0 保证极端窄屏（分屏/小屏机）也不会因下限抬宽而溢出
        var cell =
            (constraints.maxWidth - _gap * (weeks - 1)) / weeks;
        cell = cell.clamp(1.0, _maxCell);
        final step = cell + _gap;
        final gridWidth = weeks * step - _gap;
        final radius = (cell * 0.28).clamp(1.0, 2.5);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showMonthLabels) ...[
              SizedBox(
                width: gridWidth,
                child: Row(children: _buildMonthLabels(step, context)),
              ),
              const SizedBox(height: 3),
            ],
            SizedBox(
              width: gridWidth,
              child: Row(
                children: [
                  for (var w = 0; w < weeks; w++)
                    Padding(
                      padding: EdgeInsets.only(right: w == weeks - 1 ? 0 : _gap),
                      child: Column(
                        children: [
                          for (var r = 0; r < 7; r++)
                            Padding(
                              padding:
                                  EdgeInsets.only(bottom: r == 6 ? 0 : _gap),
                              child: _buildCell(columns[w][r], cell, radius),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildMonthLabels(double step, BuildContext context) {
    int? lastMonth;
    final items = <Widget>[];
    for (var w = 0; w < columns.length; w++) {
      final col = columns[w];
      DateTime? first;
      for (final d in col) {
        if (d != null) {
          first = d;
          break;
        }
      }
      var label = '';
      if (first != null && first.month != lastMonth) {
        label = '${first.month}月';
        lastMonth = first.month;
      }
      items.add(
        SizedBox(
          // 最后一列没有右侧 gap，槽宽需减去 _gap，否则整行比网格宽 1.5px 溢出
          width: w == columns.length - 1 ? step - _gap : step,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: TextStyle(fontSize: 8, color: AppColors.tt(context)),
          ),
        ),
      );
    }
    return items;
  }

  Widget _buildCell(DateTime? date, double cell, double radius) {
    if (date == null) {
      return SizedBox(width: cell, height: cell);
    }
    final isToday = date.isAtSameMomentAs(today);
    return Container(
      width: cell,
      height: cell,
      decoration: BoxDecoration(
        color: colorFor(date),
        borderRadius: BorderRadius.circular(radius),
        border: isToday
            ? Border.all(color: const Color(0xFF6366F1), width: 1)
            : null,
      ),
    );
  }
}
