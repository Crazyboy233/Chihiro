import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../constants/colors.dart';
import '../../providers/schedule_provider.dart';
import 'add_schedule_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final DateTime _focusedDay = DateTime.now();
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
      body: Consumer<ScheduleProvider>(
        builder: (context, scheduleProvider, child) {
          return _buildCustomCalendar(scheduleProvider);
        },
      ),
      floatingActionButton: FloatingActionButton(
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
    
    var currentDay = firstDayOfMonth;
    while (currentDay.weekday != DateTime.monday) {
      currentDay = currentDay.subtract(const Duration(days: 1));
    }
    
    var lastCalendarDay = lastDayOfMonth;
    while (lastCalendarDay.weekday != DateTime.sunday) {
      lastCalendarDay = lastCalendarDay.add(const Duration(days: 1));
    }
    
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
}
