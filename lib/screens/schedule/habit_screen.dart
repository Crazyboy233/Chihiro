import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../constants/colors.dart';
import '../../models/habit_goal.dart';
import '../../providers/habit_provider.dart';
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
}
