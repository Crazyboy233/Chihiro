import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../constants/colors.dart';
import '../../models/schedule.dart';
import '../../models/habit_goal.dart';
import '../../models/habit_record.dart';
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
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer2<ScheduleProvider, HabitProvider>(
        builder: (context, scheduleProvider, habitProvider, child) {
          final selectedDate = _selectedDay ?? DateTime.now();
          final todaySchedules = scheduleProvider.getSchedulesByDate(selectedDate);
          final todayHabits = habitProvider.goals;

          return CustomScrollView(
            slivers: [
            const SliverAppBar(
            title: Text('日程'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            pinned: true,
            floating: true,
            snap: true,
              ),
              SliverToBoxAdapter(
                child: _buildCalendar(scheduleProvider, habitProvider),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SectionHeaderDelegate(
                  child: Container(
                    color: AppColors.background,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      _formatDate(selectedDate),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              if (todayHabits.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '今日打卡',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return _buildHabitCard(
                          todayHabits[index],
                          selectedDate,
                          habitProvider,
                        );
                      },
                      childCount: todayHabits.length,
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '今日日程',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              if (todaySchedules.isEmpty)
                const SliverToBoxAdapter(
                  child: Card(
                    color: AppColors.surface,
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.event_note,
                              size: 48,
                              color: AppColors.textTertiary,
                            ),
                            SizedBox(height: 8),
                            Text(
                              '暂无日程',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return _buildScheduleCard(todaySchedules[index]);
                      },
                      childCount: todaySchedules.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'add_habit',
            mini: true,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddHabitScreen()),
              ).then((_) => context.read<HabitProvider>().loadGoals());
            },
            child: const Icon(Icons.emoji_events),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'add_schedule',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddScheduleScreen(selectedDate: _selectedDay),
                ),
              ).then((_) => _loadData());
            },
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(
    ScheduleProvider scheduleProvider,
    HabitProvider habitProvider,
  ) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.only(bottom: 8),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        eventLoader: (day) => _getEventsForDay(day, scheduleProvider, habitProvider),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onFormatChanged: (format) {
          if (_calendarFormat != format) {
            setState(() {
              _calendarFormat = format;
            });
          }
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
          _loadData();
        },
        calendarStyle: const CalendarStyle(
          outsideDaysVisible: false,
          markerDecoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          cellMargin: EdgeInsets.all(2),
          cellPadding: EdgeInsets.all(4),
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, day, events) {
            if (events.isEmpty) return const SizedBox();
            return _buildDayCellContent(day, scheduleProvider, habitProvider);
          },
          defaultBuilder: (context, day, focusedDay) {
            return _buildDayCell(day, focusedDay, scheduleProvider, habitProvider);
          },
          selectedBuilder: (context, day, focusedDay) {
            return _buildDayCell(day, focusedDay, scheduleProvider, habitProvider, isSelected: true);
          },
          todayBuilder: (context, day, focusedDay) {
            return _buildDayCell(day, focusedDay, scheduleProvider, habitProvider, isToday: true);
          },
        ),
        headerStyle: const HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
        ),
      ),
    );
  }

  Widget _buildDayCell(
    DateTime day,
    DateTime focusedDay,
    ScheduleProvider scheduleProvider,
    HabitProvider habitProvider, {
    bool isSelected = false,
    bool isToday = false,
  }) {
    final isCurrentMonth = day.month == focusedDay.month;
    
    return Container(
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withOpacity(0.2)
            : isToday
                ? AppColors.primary.withOpacity(0.1)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isToday
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? AppColors.primary
                  : isCurrentMonth
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: _buildDayCellContent(day, scheduleProvider, habitProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCellContent(
    DateTime day,
    ScheduleProvider scheduleProvider,
    HabitProvider habitProvider,
  ) {
    final daySchedules = scheduleProvider.getSchedulesByDate(day);
    final dayHabits = habitProvider.goals;
    final completedHabits = dayHabits.where((goal) {
      return habitProvider.isCompleted(goal.id!, day);
    }).toList();

    final children = <Widget>[];
    
    if (daySchedules.isNotEmpty) {
      children.add(
        Container(
          height: 4,
          width: 4,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
      );
    }
    
    if (completedHabits.isNotEmpty) {
      children.add(
        Container(
          height: 4,
          width: 4,
          decoration: const BoxDecoration(
            color: AppColors.income,
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 2,
      runSpacing: 2,
      alignment: WrapAlignment.center,
      children: children,
    );
  }

  List<dynamic> _getEventsForDay(
    DateTime day,
    ScheduleProvider scheduleProvider,
    HabitProvider habitProvider,
  ) {
    final schedules = scheduleProvider.getSchedulesByDate(day);
    final completedHabits = habitProvider.goals.where((goal) {
      return habitProvider.isCompleted(goal.id!, day);
    }).toList();
    return [...schedules, ...completedHabits];
  }

  Widget _buildHabitCard(
    HabitGoal goal,
    DateTime date,
    HabitProvider habitProvider,
  ) {
    final isCompleted = habitProvider.isCompleted(goal.id!, date);
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Color(int.parse('0xFF${goal.color.replaceFirst('#', '')}')).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(goal.icon, style: const TextStyle(fontSize: 24)),
          ),
        ),
        title: Text(
          goal.name,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        subtitle: goal.description != null
            ? Text(
                goal.description!,
                style: const TextStyle(color: AppColors.textSecondary),
              )
            : null,
        trailing: IconButton(
          icon: Icon(
            isCompleted ? Icons.check_circle : Icons.check_circle_outline,
            color: isCompleted ? AppColors.income : AppColors.textTertiary,
            size: 32,
          ),
          onPressed: () async {
            final dateStr = date.toIso8601String().split('T')[0];
            final now = DateTime.now();
            
            if (isCompleted) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('今日已打卡')),
                );
              }
            } else {
              final record = HabitRecord(
                goalId: goal.id!,
                date: dateStr,
                isCompleted: 1,
                createdAt: now.toIso8601String(),
              );
              await habitProvider.addRecord(record);
              await habitProvider.loadRecords(goal.id!, date, date);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('打卡成功！')),
                );
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildScheduleCard(Schedule schedule) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Icon(Icons.event, color: AppColors.primary),
          ),
        ),
        title: Text(
          schedule.title,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatTime(schedule.startTime),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (schedule.description != null)
              Text(
                schedule.description!,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${date.year}年${date.month}月${date.day}日 ${weekdays[date.weekday - 1]}';
  }

  String _formatTime(String timeStr) {
    try {
      final time = DateTime.parse(timeStr);
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '全天';
    }
  }
}

class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SectionHeaderDelegate({required this.child});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  double get maxExtent => 50;

  @override
  double get minExtent => 50;

  @override
  bool shouldRebuild(_SectionHeaderDelegate oldDelegate) {
    return false;
  }
}
