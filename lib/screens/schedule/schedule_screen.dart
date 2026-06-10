import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../constants/colors.dart';
import '../../models/habit_goal.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/habit_provider.dart';
import 'add_schedule_screen.dart';
import 'add_habit_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime _habitFocusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

    context.read<ScheduleProvider>().loadSchedules(
      DateTime(firstDay.year, firstDay.month - 1, 1),
      DateTime(lastDay.year, lastDay.month + 1, 0),
    );
    context.read<HabitProvider>().loadGoals();
  }

  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(firstDayOfYear).inDays + 1;
    final adjustedWeekday = (firstDayOfYear.weekday + 5) % 7 + 1;
    return ((dayOfYear - adjustedWeekday + 10) / 7).floor();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Row(
        children: [
          // 左侧：日程日历
          Expanded(
            flex: 2,
            child: Consumer<ScheduleProvider>(
              builder: (context, scheduleProvider, child) {
                return _buildCustomCalendar(scheduleProvider);
              },
            ),
          ),
          // 分隔线
          Container(
            width: 1,
            color: Colors.grey[200],
          ),
          // 右侧：打卡功能
          Expanded(
            flex: 1,
            child: Consumer<HabitProvider>(
              builder: (context, habitProvider, child) {
                return _buildHabitSection(habitProvider);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButtons(),
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
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_focusedDay.year}.${_focusedDay.month.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, color: Colors.black87),
        ],
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

  Widget _buildCustomCalendar(ScheduleProvider scheduleProvider) {
    return Column(
      children: [
        _buildWeekdaysHeader(),
        Expanded(
          child: _buildCalendarGrid(scheduleProvider),
        ),
      ],
    );
  }

  Widget _buildWeekdaysHeader() {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Container(),
          ),
          ...List.generate(7, (index) {
            final isWeekend = index >= 5;
            return Expanded(
              child: Container(
                alignment: Alignment.center,
                child: Text(
                  weekdays[index],
                  style: TextStyle(
                    fontSize: 14,
                    color: isWeekend ? Colors.orange : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(ScheduleProvider scheduleProvider) {
    final days = _generateCalendarDays();
    final weekCount = (days.length / 7).ceil();
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final rowHeight = (constraints.maxHeight) / weekCount;
        
        return Column(
          children: List.generate(weekCount, (weekIndex) {
            final weekDays = days.skip(weekIndex * 7).take(7).toList();
            return Expanded(
              child: _buildWeekRow(weekDays, scheduleProvider, rowHeight, weekIndex),
            );
          }),
        );
      },
    );
  }

  List<DateTime> _generateCalendarDays() {
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    
    // 找到这个月第一天之前的周一
    var currentDay = firstDayOfMonth;
    while (currentDay.weekday != DateTime.monday) {
      currentDay = currentDay.subtract(const Duration(days: 1));
    }
    
    // 找到这个月最后一天之后的周日
    var lastCalendarDay = lastDayOfMonth;
    while (lastCalendarDay.weekday != DateTime.sunday) {
      lastCalendarDay = lastCalendarDay.add(const Duration(days: 1));
    }
    
    // 生成从第一个周一到最后一个周日之间的所有日期
    final days = <DateTime>[];
    while (currentDay.isBefore(lastCalendarDay) || currentDay.isAtSameMomentAs(lastCalendarDay)) {
      days.add(currentDay);
      currentDay = currentDay.add(const Duration(days: 1));
    }
    
    return days;
  }

  Widget _buildWeekRow(
    List<DateTime> weekDays,
    ScheduleProvider scheduleProvider,
    double rowHeight,
    int weekIndex,
  ) {
    final weekNumber = _getWeekNumber(weekDays.first);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Container(
              alignment: Alignment.center,
              child: Text(
                '第$weekNumber周',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                ),
              ),
            ),
          ),
          ...weekDays.map((day) {
            return Expanded(
              child: _buildDayCell(day, scheduleProvider, rowHeight),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDayCell(
    DateTime day,
    ScheduleProvider scheduleProvider,
    double rowHeight,
  ) {
    final isCurrentMonth = day.month == _focusedDay.month;
    final isWeekend = day.weekday == DateTime.sunday || day.weekday == DateTime.saturday;
    final isToday = isSameDay(day, DateTime.now());
    final isSelected = _selectedDay != null && isSameDay(day, _selectedDay);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDay = day;
        });
      },
      child: Container(
        height: rowHeight,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.grey[200]!, width: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 4, right: 6),
              child: Stack(
                children: [
                  if (isToday || isSelected)
                    Positioned(
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Center(
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? Colors.white
                              : isToday
                                  ? AppColors.primary
                                  : isCurrentMonth
                                      ? isWeekend
                                          ? Colors.orange
                                          : Colors.black87
                                      : Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildDayCellContent(day, scheduleProvider, rowHeight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCellContent(
    DateTime day,
    ScheduleProvider scheduleProvider,
    double rowHeight,
  ) {
    final daySchedules = scheduleProvider.getSchedulesByDate(day);

    final children = <Widget>[];
    final maxItems = rowHeight > 100 ? 4 : 3;
    
    for (var i = 0; i < daySchedules.length && children.length < maxItems; i++) {
      final schedule = daySchedules[i];
      final color = schedule.color != null
          ? Color(int.parse('0xFF${schedule.color!.replaceFirst('#', '')}'))
          : const Color(0xFFFFB74D);
      
      final displayText = schedule.title.length > 6
          ? schedule.title.substring(0, 6)
          : schedule.title;
      
      children.add(
        Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            displayText,
            style: TextStyle(
              color: Colors.white,
              fontSize: rowHeight > 100 ? 10 : 9,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    final remaining = daySchedules.length - maxItems;
    if (remaining > 0) {
      children.add(
        Text(
          '+$remaining',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: rowHeight > 100 ? 10 : 9,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  // 打卡功能区域
  Widget _buildHabitSection(HabitProvider habitProvider) {
    if (habitProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: AppColors.background,
      child: Column(
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
      ),
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
    final hasCompletedHabits = completedGoalIds.isNotEmpty;
    final totalGoals = habitProvider.goals.length;
    final completionRate = totalGoals > 0 ? completedGoalIds.length / totalGoals : 0.0;

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

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: isToday ? Border.all(color: AppColors.primary, width: 2) : null,
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : isOutside
                    ? Colors.grey[400]
                    : hasCompletedHabits
                        ? Colors.white
                        : Colors.black87,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildHabitList(HabitProvider habitProvider) {
    final goals = habitProvider.goals;
    final today = _selectedDay ?? DateTime.now();

    if (goals.isEmpty) {
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
              '还没有打卡目标',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击右下角的 + 添加目标',
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

  Widget _buildHabitItem(
    HabitGoal goal,
    bool isCompleted,
    HabitProvider habitProvider,
    DateTime date,
  ) {
    final color = Color(int.parse('0xFF${goal.color.replaceFirst('#', '')}'));

    return GestureDetector(
      onTap: () async {
        if (goal.id != null) {
          await habitProvider.toggleHabit(goal.id!, date);
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
                  if (goal.description != null && goal.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        goal.description!,
                        style: TextStyle(
                          fontSize: 14,
                          color: isCompleted ? Colors.green[500] : Colors.grey[600],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green : Colors.grey[200],
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted ? Colors.green : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
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
        const SizedBox(height: 16),
        FloatingActionButton(
          heroTag: 'add_schedule',
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddScheduleScreen(selectedDate: _selectedDay),
              ),
            );
            if (mounted) {
              _loadData();
            }
          },
          backgroundColor: const Color(0xFFFF9800),
          child: const Icon(Icons.add, size: 32),
        ),
      ],
    );
  }
}
