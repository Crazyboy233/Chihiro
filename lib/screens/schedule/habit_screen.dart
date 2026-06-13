import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../constants/colors.dart';
import '../../models/habit_goal.dart';
import '../../providers/habit_provider.dart';
import '../../utils/holiday_service.dart';
import 'add_habit_screen.dart';

class HabitScreen extends StatefulWidget {
  const HabitScreen({super.key});

  @override
  State<HabitScreen> createState() => _HabitScreenState();
}

class _HabitScreenState extends State<HabitScreen> {
  DateTime? _selectedDay;
  DateTime _habitFocusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HabitProvider>().loadGoals();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Consumer<HabitProvider>(
        builder: (context, habitProvider, child) {
          return _buildHabitSection(habitProvider);
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_habit',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddHabitScreen()),
          );
          if (mounted) {
            context.read<HabitProvider>().loadGoals();
          }
        },
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.add_task, size: 28),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.black87),
        onPressed: () {},
      ),
      title: const Text(
        '打卡',
        style: TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.black87),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildHabitSection(HabitProvider habitProvider) {
    if (habitProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // 打卡日历
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: _buildHabitCalendar(habitProvider),
        ),
        // 分隔线
        Container(height: 8, color: AppColors.background),
        // 打卡目标列表
        Expanded(
          child: _buildHabitList(habitProvider),
        ),
      ],
    );
  }

  Widget _buildHabitCalendar(HabitProvider habitProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_habitFocusedDay.year}年${_habitFocusedDay.month}月',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _habitFocusedDay = DateTime(
                        _habitFocusedDay.year,
                        _habitFocusedDay.month - 1,
                      );
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _habitFocusedDay = DateTime(
                        _habitFocusedDay.year,
                        _habitFocusedDay.month + 1,
                      );
                    });
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _habitFocusedDay,
          calendarFormat: CalendarFormat.month,
          availableCalendarFormats: const {CalendarFormat.month: 'Month'},
          headerVisible: false,
          startingDayOfWeek: StartingDayOfWeek.monday,
          daysOfWeekStyle: const DaysOfWeekStyle(
            weekdayStyle: TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
            weekendStyle: TextStyle(
              fontSize: 12,
              color: Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
          calendarStyle: CalendarStyle(
            tablePadding: const EdgeInsets.symmetric(vertical: 4),
            cellMargin: const EdgeInsets.all(0),
            cellPadding: const EdgeInsets.all(0),
            outsideDaysVisible: true,
            defaultDecoration: BoxDecoration(color: Colors.grey[50]),
          ),
          daysOfWeekHeight: 24,
          rowHeight: 60,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _habitFocusedDay = focusedDay;
            });
          },
          onPageChanged: (focusedDay) {
            setState(() {
              _habitFocusedDay = focusedDay;
            });
          },
          calendarBuilders: CalendarBuilders(
            dowBuilder: (context, day) {
              const weekDays = ['一', '二', '三', '四', '五', '六', '日'];
              final label = weekDays[day.weekday - 1];
              final isWeekend = day.weekday == 6 || day.weekday == 7;
              return Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isWeekend ? Colors.orange[700] : Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
            defaultBuilder: (context, day, focusedDay) {
              return _buildHabitDayCell(day, habitProvider);
            },
            todayBuilder: (context, day, focusedDay) {
              return _buildHabitDayCell(day, habitProvider, isToday: true);
            },
            selectedBuilder: (context, day, focusedDay) {
              return _buildHabitDayCell(day, habitProvider, isSelected: true);
            },
            outsideBuilder: (context, day, focusedDay) {
              return _buildHabitDayCell(day, habitProvider, isOutside: true);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHabitDayCell(
    DateTime day,
    HabitProvider habitProvider, {
    bool isToday = false,
    bool isSelected = false,
    bool isOutside = false,
  }) {
    final completedGoalIds = habitProvider.getCompletedGoalIdsForDate(day);
    final goalsToday = habitProvider.goals.where((g) => habitProvider.shouldShowOnDate(g, day)).toList();
    final totalGoals = goalsToday.length;
    final completedToday = goalsToday.where((g) => g.id != null && habitProvider.isCompleted(g.id!, day)).length;
    final hasCompletedHabits = completedToday > 0;
    final completionRate = totalGoals > 0 ? completedToday / totalGoals : 0.0;

    // 打卡背景颜色
    Color backgroundColor;
    if (hasCompletedHabits) {
      if (completionRate == 1.0) {
        backgroundColor = Colors.green[400]!;
      } else if (completionRate >= 0.5) {
        backgroundColor = Colors.lightGreen[300]!;
      } else {
        backgroundColor = Colors.lightGreen[100]!;
      }
    } else {
      backgroundColor = Colors.white;
    }

    // 节假日信息
    final holidayInfo = HolidayService().getHolidayInfo(day);
    final isHoliday = holidayInfo?.isHoliday ?? false;
    final isWorkdayShift = holidayInfo?.isMakeupWorkday ?? false;
    final holidayName = holidayInfo?.name;
    final isWeekend = day.weekday == 6 || day.weekday == 7;

    // 日期数字颜色
    Color dayColor;
    if (isSelected) {
      dayColor = Colors.white;
    } else if (isOutside) {
      dayColor = Colors.grey[400]!;
    } else if (hasCompletedHabits) {
      dayColor = Colors.white;
    } else if (isHoliday) {
      dayColor = Colors.green[700]!;
    } else if (isWeekend) {
      dayColor = Colors.orange[700]!;
    } else {
      dayColor = Colors.black87;
    }

    // 周数（仅周一显示）
    final isMonday = day.weekday == 1;
    final weekOfYear = _getWeekOfYear(day);

    // 「休」「班」小标签
    Widget? tag;
    if (!isOutside) {
      if (isHoliday) {
        tag = Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            '休',
            style: TextStyle(
              fontSize: 8,
              color: Colors.green[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      } else if (isWorkdayShift) {
        tag = Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            '班',
            style: TextStyle(
              fontSize: 8,
              color: Colors.orange[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
    }

    return Container(
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: isToday ? Border.all(color: AppColors.primary, width: 2) : null,
      ),
      child: Stack(
        children: [
          // 左上角：周数（仅周一）
          if (isMonday && !isOutside)
            Positioned(
              top: 0,
              left: 0,
              child: Text(
                '第$weekOfYear周',
                style: TextStyle(
                  fontSize: 8,
                  color: isSelected
                      ? Colors.white70
                      : hasCompletedHabits
                          ? Colors.white70
                          : Colors.grey[500],
                ),
              ),
            ),
          // 右上角：休/班标签
          if (tag != null)
            Positioned(
              top: 0,
              right: 0,
              child: tag,
            ),
          // 中心：日期数字
          Center(
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 13,
                color: dayColor,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          // 底部：节假日名称
          if (holidayName != null && holidayName.isNotEmpty && !isOutside)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  holidayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8,
                    color: isSelected
                        ? Colors.white70
                        : hasCompletedHabits
                            ? Colors.white70
                            : isHoliday
                                ? Colors.green[700]
                                : Colors.grey[600],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  int _getWeekOfYear(DateTime date) {
    final firstDay = DateTime(date.year, 1, 1);
    final diff = date.difference(firstDay).inDays;
    final weekdayOffset = firstDay.weekday - 1;
    final week = ((diff + weekdayOffset) / 7).floor() + 1;
    return week;
  }

  Widget _buildHabitList(HabitProvider habitProvider) {
    final today = _selectedDay ?? DateTime.now();
    final goals = habitProvider.goals.where((g) => habitProvider.shouldShowOnDate(g, today)).toList();

    if (goals.isEmpty) {
      final hasAnyGoal = habitProvider.goals.isNotEmpty;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fitness_center_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              hasAnyGoal ? '今天没有打卡目标' : '还没有打卡目标',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasAnyGoal ? '选一个其他日期看看' : '点击右下角的 + 添加目标',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: goals.length,
      itemBuilder: (context, index) {
        final goal = goals[index];
        final isCompleted = goal.id != null ? habitProvider.isCompleted(goal.id!, today) : false;

        return _buildHabitItem(goal, isCompleted, habitProvider, today);
      },
    );
  }

  String _getFrequencyLabel(HabitGoal goal) {
    switch (goal.frequency) {
      case 'daily':
        return '每天';
      case 'weekdays':
        return '工作日';
      case 'weekly':
        return '每周';
      case 'custom':
        if (goal.targetDays != null && goal.targetDays!.isNotEmpty) {
          const names = ['一', '二', '三', '四', '五', '六', '日'];
          final days = goal.targetDays!
              .split(',')
              .map((e) => int.tryParse(e))
              .whereType<int>()
              .toList()
            ..sort();
          return '周${days.map((d) => names[d - 1]).join('、')}';
        }
        return '自定义';
      case 'interval':
        return '每隔${goal.customIntervalDays ?? 1}天';
      default:
        return '每天';
    }
  }

  Widget _buildHabitItem(
    HabitGoal goal,
    bool isCompleted,
    HabitProvider habitProvider,
    DateTime date,
  ) {
    final color = Color(int.parse('0xFF${goal.color.replaceFirst('#', '')}'));

    return GestureDetector(
      onTap: () {
        if (goal.id != null) {
          _showGoalDetail(context, goal, habitProvider);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCompleted ? Colors.green[50] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCompleted ? Colors.green[300]! : Colors.grey[200]!,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green[100] : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  goal.icon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isCompleted ? Colors.green[700] : Colors.black87,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getFrequencyLabel(goal),
                    style: TextStyle(
                      fontSize: 13,
                      color: isCompleted ? Colors.green[500] : Colors.grey[500],
                    ),
                  ),
                  if (goal.description != null && goal.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        goal.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isCompleted ? Colors.green[500] : Colors.grey[600],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () async {
                if (goal.id != null) {
                  await habitProvider.toggleHabit(goal.id!, date);
                }
              },
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isCompleted ? Colors.green : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCompleted ? Colors.green : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 22)
                    : const Icon(Icons.circle_outlined, color: Colors.grey, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 打卡目标详情日历弹窗
  void _showGoalDetail(BuildContext context, HabitGoal goal, HabitProvider habitProvider) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _GoalDetailDialog(
          goal: goal,
          habitProvider: habitProvider,
        );
      },
    );
  }
}

// 打卡目标详情日历弹窗组件
class _GoalDetailDialog extends StatefulWidget {
  final HabitGoal goal;
  final HabitProvider habitProvider;

  const _GoalDetailDialog({
    required this.goal,
    required this.habitProvider,
  });

  @override
  State<_GoalDetailDialog> createState() => _GoalDetailDialogState();
}

class _GoalDetailDialogState extends State<_GoalDetailDialog> {
  late DateTime _focusedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = DateTime(now.year, now.month, 1);
    // 打开弹窗时加载初始月份数据
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadMonthData(_focusedDay);
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadMonthData(DateTime monthStart) async {
    // 加载该月份的打卡记录
    final firstDay = DateTime(monthStart.year, monthStart.month, 1);
    final lastDay = DateTime(monthStart.year, monthStart.month + 1, 0);
    if (widget.goal.id != null) {
      await widget.habitProvider.loadAllRecordsForMonth(firstDay, lastDay);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse('0xFF${widget.goal.color.replaceFirst('#', '')}'));

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部：目标信息
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(widget.goal.icon, style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.goal.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getFrequencyLabelForDialog(widget.goal),
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 月份切换
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_focusedDay.year}年${_focusedDay.month}月',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () async {
                        final newMonth = DateTime(
                          _focusedDay.year,
                          _focusedDay.month - 1,
                          1,
                        );
                        await _loadMonthData(newMonth);
                        setState(() {
                          _focusedDay = newMonth;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () async {
                        final newMonth = DateTime(
                          _focusedDay.year,
                          _focusedDay.month + 1,
                          1,
                        );
                        await _loadMonthData(newMonth);
                        setState(() {
                          _focusedDay = newMonth;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 星期表头
            Row(
              children: List.generate(7, (index) {
                const weekDays = ['一', '二', '三', '四', '五', '六', '日'];
                final isWeekend = index >= 5;
                return Expanded(
                  child: Center(
                    child: Text(
                      weekDays[index],
                      style: TextStyle(
                        fontSize: 12,
                        color: isWeekend ? Colors.orange[700] : Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),

            // 日历格子
            _buildCalendarGrid(color),
            const SizedBox(height: 16),

            // 图例
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegend(color, '已打卡', true),
                const SizedBox(width: 16),
                _buildLegend(Colors.grey[300]!, '未打卡', false),
                const SizedBox(width: 16),
                _buildLegend(color.withOpacity(0.15), '该日无需打卡', false,
                    borderColor: Colors.grey[200]!),
              ],
            ),
            const SizedBox(height: 8),

            // 统计信息
            _buildMonthStats(color),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(Color color) {
    // 计算本月第一天的星期偏移（周一起始）
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final daysInMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
    final weekdayOfFirst = firstDayOfMonth.weekday; // 1=周一, 7=周日
    final leadingEmptyDays = weekdayOfFirst - 1;

    // 计算上月末尾几天需要显示的数量
    final prevMonthDays = DateTime(_focusedDay.year, _focusedDay.month, 0).day;
    final totalCells = ((leadingEmptyDays + daysInMonth + 6) / 7).ceil() * 7;
    final trailingEmpty = totalCells - (leadingEmptyDays + daysInMonth);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 生成格子数据
    final List<Map<String, dynamic>> cells = [];

    // 上月末尾（灰色显示）
    for (int i = leadingEmptyDays; i > 0; i--) {
      final day = prevMonthDays - i + 1;
      final date = DateTime(_focusedDay.year, _focusedDay.month - 1, day);
      cells.add({'date': date, 'isOutside': true});
    }

    // 本月
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_focusedDay.year, _focusedDay.month, day);
      cells.add({'date': date, 'isOutside': false});
    }

    // 下月开头（灰色显示）
    for (int day = 1; day <= trailingEmpty; day++) {
      final date = DateTime(_focusedDay.year, _focusedDay.month + 1, day);
      cells.add({'date': date, 'isOutside': true});
    }

    return Column(
      children: List.generate((cells.length / 7).ceil(), (rowIndex) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: List.generate(7, (colIndex) {
              final cellIndex = rowIndex * 7 + colIndex;
              if (cellIndex >= cells.length) {
                return const Expanded(child: SizedBox.shrink());
              }
              final cell = cells[cellIndex];
              final date = cell['date'] as DateTime;
              final isOutside = cell['isOutside'] as bool;
              final isToday = !isOutside && date.isAtSameMomentAs(today);

              // 判断该目标在这一天是否应该显示（应该打卡）
              final shouldShow = !isOutside && widget.habitProvider.shouldShowOnDate(widget.goal, date);
              final isCompleted = shouldShow &&
                  widget.goal.id != null &&
                  widget.habitProvider.isCompleted(widget.goal.id!, date);

              Color bgColor;
              Color textColor;
              Color? borderColor;

              if (isOutside) {
                bgColor = Colors.transparent;
                textColor = Colors.grey[300]!;
              } else if (!shouldShow) {
                // 该目标在这一天无需打卡（比如周末、工作日频率等）
                bgColor = color.withOpacity(0.08);
                textColor = Colors.grey[400]!;
              } else if (isCompleted) {
                bgColor = color;
                textColor = Colors.white;
              } else {
                bgColor = Colors.white;
                textColor = Colors.black87;
                borderColor = Colors.grey[200];
              }

              return Expanded(
                child: Center(
                  child: Container(
                    width: 34,
                    height: 34,
                    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: isToday
                          ? Border.all(color: color, width: 2)
                          : borderColor != null
                              ? Border.all(color: borderColor, width: 1)
                              : null,
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 13,
                          color: textColor,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildLegend(Color color, String label, bool isFilled, {Color? borderColor}) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: borderColor != null ? Border.all(color: borderColor, width: 1) : null,
          ),
          child: isFilled
              ? const Icon(Icons.check, color: Colors.white, size: 12)
              : null,
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildMonthStats(Color color) {
    // 统计本月该目标的打卡情况
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final daysInMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;

    int shouldDays = 0;
    int completedDays = 0;

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_focusedDay.year, _focusedDay.month, day);
      if (widget.habitProvider.shouldShowOnDate(widget.goal, date)) {
        shouldDays++;
        if (widget.goal.id != null && widget.habitProvider.isCompleted(widget.goal.id!, date)) {
          completedDays++;
        }
      }
    }

    final rate = shouldDays > 0 ? (completedDays / shouldDays * 100).toStringAsFixed(0) : '0';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('需打卡', '$shouldDays 天'),
          _buildStatItem('已完成', '$completedDays 天',
              color: completedDays > 0 ? Colors.green[700] : null),
          _buildStatItem('完成率', '$rate%', color: color),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  String _getFrequencyLabelForDialog(HabitGoal goal) {
    switch (goal.frequency) {
      case 'daily':
        return '每天';
      case 'weekdays':
        return '工作日';
      case 'weekly':
        return '每周';
      case 'custom':
        if (goal.targetDays != null && goal.targetDays!.isNotEmpty) {
          const names = ['一', '二', '三', '四', '五', '六', '日'];
          final days = goal.targetDays!
              .split(',')
              .map((e) => int.tryParse(e))
              .whereType<int>()
              .toList()
            ..sort();
          return '周${days.map((d) => names[d - 1]).join('、')}';
        }
        return '自定义';
      case 'interval':
        return '每隔${goal.customIntervalDays ?? 1}天';
      default:
        return '每天';
    }
  }
}
