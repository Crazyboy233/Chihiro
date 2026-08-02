import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/countdown_day.dart';
import '../../providers/countdown_provider.dart';
import 'add_countdown_screen.dart';

/// 倒数日列表视图（嵌入日程 Tab 顶部页签中，非独立页面）
///
/// 分组展示：
/// 1. 今天（到期/起始当天，整卡高亮）
/// 2. 倒数（目标日未来，按剩余天数升序）
/// 3. 正数（起始日过去，按已坚持天数降序）
/// 4. 已过（目标日已过，淡化显示）
class CountdownView extends StatelessWidget {
  const CountdownView({super.key});

  static const _weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    return Consumer<CountdownProvider>(
      builder: (context, provider, _) {
        final days = provider.days;

        if (days.isEmpty) {
          return _buildEmptyState(context);
        }

        final todayItems = <CountdownDay>[];
        final upcoming = <CountdownDay>[];
        final countups = <CountdownDay>[];
        final passed = <CountdownDay>[];

        for (final d in days) {
          if (d.isToday) {
            todayItems.add(d);
          } else if (d.isCountup) {
            countups.add(d);
          } else if (d.daysDiff > 0) {
            upcoming.add(d);
          } else {
            passed.add(d);
          }
        }
        upcoming.sort((a, b) => a.daysDiff.compareTo(b.daysDiff));
        countups.sort((a, b) => b.elapsedDays.compareTo(a.elapsedDays));
        passed.sort((a, b) => a.passedDays.compareTo(b.passedDays));

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            if (todayItems.isNotEmpty) ...[
              _buildSectionHeader(context, '今天', Icons.star_rounded),
              ...todayItems.map((d) => _CountdownCard(day: d)),
            ],
            if (upcoming.isNotEmpty) ...[
              _buildSectionHeader(context, '倒数', Icons.hourglass_top_rounded),
              ...upcoming.map((d) => _CountdownCard(day: d)),
            ],
            if (countups.isNotEmpty) ...[
              _buildSectionHeader(context, '正数', Icons.trending_up_rounded),
              ...countups.map((d) => _CountdownCard(day: d)),
            ],
            if (passed.isNotEmpty) ...[
              _buildSectionHeader(context, '已过', Icons.history_rounded),
              ...passed.map((d) => _CountdownCard(day: d)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.ts(context)),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ts(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hourglass_empty_rounded,
            size: 64,
            color: AppColors.tt(context),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有倒数日',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.ts(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '点击右下角 + 添加一个期待的日子吧',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.tt(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownCard extends StatelessWidget {
  final CountdownDay day;

  const _CountdownCard({required this.day});

  Color get _color => day.color != null
      ? Color(int.parse('0xFF${day.color!.replaceFirst('#', '')}'))
      : const Color(0xFF6366F1);

  String get _dateText {
    final d = DateTime.parse(day.targetDate);
    final weekday = CountdownView._weekdayNames[d.weekday - 1];
    return '${d.year}年${d.month}月${d.day}日 周$weekday';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _color;
    final highlight = day.isToday;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddCountdownScreen(day: day),
          ),
        );
        if (context.mounted) {
          context.read<CountdownProvider>().loadCountdownDays();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          // 今天到期：整卡用主题色高亮
          gradient: highlight
              ? LinearGradient(
                  colors: [color, color.withValues(alpha: 0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: highlight ? null : cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: highlight ? null : Border.all(color: AppColors.bd(context), width: 1),
          boxShadow: highlight
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 左侧颜色条
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: highlight ? Colors.white.withValues(alpha: 0.7) : color,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(14),
                  ),
                ),
              ),
              // 标题与日期
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              day.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: highlight ? Colors.white : cs.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildTypeBadge(highlight, color),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        day.isCountup ? '起始日 $_dateText' : '目标日 $_dateText',
                        style: TextStyle(
                          fontSize: 12,
                          color: highlight
                              ? Colors.white.withValues(alpha: 0.85)
                              : AppColors.ts(context),
                        ),
                      ),
                      if (day.note != null && day.note!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          day.note!,
                          style: TextStyle(
                            fontSize: 12,
                            color: highlight
                                ? Colors.white.withValues(alpha: 0.75)
                                : AppColors.tt(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // 右侧大数字
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _buildNumberBlock(context, highlight, color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(bool highlight, Color color) {
    final isCountup = day.isCountup;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: highlight
            ? Colors.white.withValues(alpha: 0.25)
            : (isCountup
                ? AppColors.secondary.withValues(alpha: 0.12)
                : color.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isCountup ? '正数' : '倒数',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: highlight
              ? Colors.white
              : (isCountup ? AppColors.secondary : color),
        ),
      ),
    );
  }

  List<Widget> _buildNumberBlock(BuildContext context, bool highlight, Color color) {
    final bigStyle = TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.bold,
      height: 1.1,
      color: highlight ? Colors.white : color,
    );
    final labelStyle = TextStyle(
      fontSize: 11,
      color: highlight
          ? Colors.white.withValues(alpha: 0.85)
          : AppColors.tt(context),
    );

    if (day.isToday) {
      if (day.isCountup) {
        return [
          Text('今天开始', style: labelStyle),
          Text('第1天', style: bigStyle.copyWith(fontSize: 22)),
        ];
      }
      return [
        Text('就是', style: labelStyle),
        Text('今天', style: bigStyle.copyWith(fontSize: 22)),
      ];
    }
    if (day.isCountup) {
      return [
        Text('已坚持', style: labelStyle),
        Text('${day.elapsedDays}', style: bigStyle),
        Text('天', style: labelStyle),
      ];
    }
    if (day.daysDiff > 0) {
      return [
        Text('还有', style: labelStyle),
        Text('${day.remainingDays}', style: bigStyle),
        Text('天', style: labelStyle),
      ];
    }
    // 已过
    return [
      Text('已过', style: labelStyle),
      Text(
        '${day.passedDays}',
        style: bigStyle.copyWith(color: AppColors.tt(context)),
      ),
      Text('天', style: labelStyle),
    ];
  }
}
