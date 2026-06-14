import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../constants/colors.dart';
import '../../models/schedule.dart';
import '../../providers/schedule_provider.dart';
import '../../utils/holiday_service.dart';
import 'add_schedule_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await HolidayService().ensureInitialized();
      // 不阻塞地尝试在线刷新（可选）
      try {
        HolidayService().tryRefreshOnline();
      } catch (_) {}
      if (mounted) {
        setState(() {});
      }
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

  // ---------- 月份/年份导航 ----------

  void _changeMonth(int delta) {
    setState(() {
      _focusedDay = DateTime(
        _focusedDay.year,
        _focusedDay.month + delta,
        1,
      );
    });
    _loadData();
  }

  void _jumpTo(int year, int month) {
    setState(() {
      _focusedDay = DateTime(year, month, 1);
    });
    _loadData();
    Navigator.of(context).pop();
  }

  void _showYearMonthPicker() {
    final now = DateTime.now();
    // 年范围：2025 年 ~ 当前年 + 1（上限随时间动态变化）
    const minYear = 2025;
    final maxYear = now.year + 1;

    int pickYear = _focusedDay.year;
    if (pickYear < minYear) pickYear = minYear;
    if (pickYear > maxYear) pickYear = maxYear;
    int pickMonth = _focusedDay.month;

    const months = ['1月', '2月', '3月', '4月', '5月', '6月',
                    '7月', '8月', '9月', '10月', '11月', '12月'];

    showDialog(
      context: context,
      builder: (context) {
        return _YearMonthPickerDialog(
          initialYear: pickYear,
          initialMonth: pickMonth,
          minYear: minYear,
          maxYear: maxYear,
          months: months,
          onConfirmed: (year, month) {
            _jumpTo(year, month);
          },
        );
      },
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
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 0.5)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              // 上个月
              IconButton(
                icon: Icon(Icons.chevron_left, color: Colors.grey[700], size: 28),
                onPressed: () => _changeMonth(-1),
              ),
              const Spacer(),
              // 标题（可点击，弹出年月选择器）
              GestureDetector(
                onTap: _showYearMonthPicker,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_focusedDay.year}.${_focusedDay.month.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, color: Colors.grey[700]),
                  ],
                ),
              ),
              const Spacer(),
              // 下个月
              IconButton(
                icon: Icon(Icons.chevron_right, color: Colors.grey[700], size: 28),
                onPressed: () => _changeMonth(1),
              ),
              // 搜索
              IconButton(
                icon: Icon(Icons.search, color: Colors.grey[700]),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
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
        children: List.generate(7, (index) {
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
        children: weekDays.asMap().entries.map((entry) {
          final index = entry.key;
          final day = entry.value;
          final showWeekNumber = index == 0; // 只在周一格子显示周数
          return Expanded(
            child: _buildDayCell(day, scheduleProvider, rowHeight,
                weekNumber: showWeekNumber ? weekNumber : null),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDayCell(
    DateTime day,
    ScheduleProvider scheduleProvider,
    double rowHeight, {
    int? weekNumber,
  }) {
    final isCurrentMonth = day.month == _focusedDay.month;
    final isWeekend = day.weekday == DateTime.sunday || day.weekday == DateTime.saturday;
    final isToday = isSameDay(day, DateTime.now());
    final isSelected = _selectedDay != null && isSameDay(day, _selectedDay);
    // 节假日信息
    final holidayInfo = HolidayService().getHolidayInfo(day);
    final isPublicHoliday = holidayInfo.isHoliday;
    final isMakeupWorkday = holidayInfo.isMakeupWorkday;
    final holidayName = holidayInfo.name;

    Color getDateColor() {
      if (isSelected) return Colors.white;
      if (!isCurrentMonth) return Colors.grey[400]!;
      if (isToday) return AppColors.primary;
      // 节假日显示绿色
      if (isPublicHoliday) return Colors.green[700]!;
      if (isWeekend) return Colors.orange;
      return Colors.black87;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDay = day;
        });
        _showDayDetails(day, scheduleProvider);
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
              child: SizedBox(
                height: 28,
                child: Row(
                  mainAxisAlignment: weekNumber != null
                      ? MainAxisAlignment.spaceBetween
                      : MainAxisAlignment.start,
                  children: [
                    if (weekNumber != null)
                      Text(
                        '第$weekNumber周',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey[500],
                        ),
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          children: [
                            if (isToday || isSelected)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.primary.withValues(alpha: 0.1),
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
                                    color: getDateColor(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isMakeupWorkday && isCurrentMonth)
                          Container(
                            margin: const EdgeInsets.only(left: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: Colors.orange[200]!, width: 0.5),
                            ),
                            child: Text(
                              '班',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (isPublicHoliday && isCurrentMonth)
                          Container(
                            margin: const EdgeInsets.only(left: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: Colors.green[200]!, width: 0.5),
                            ),
                            child: Text(
                              '休',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // 节假日名称
            if (holidayName.isNotEmpty && isCurrentMonth)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  holidayName,
                  style: TextStyle(
                    fontSize: 10,
                    color: isPublicHoliday ? Colors.green[700]! : Colors.orange[700]!,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

  void _showDayDetails(DateTime day, ScheduleProvider scheduleProvider) {
    final isToday = isSameDay(day, DateTime.now());
    final weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];
    final holidayInfo = HolidayService().getHolidayInfo(day);
    final holidayTitle = holidayInfo.name;
    final isHoliday = holidayInfo.isHoliday;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // 用 Consumer 包裹，使弹窗响应 provider 数据变化（例如编辑页删除后刷新）
        return Consumer<ScheduleProvider>(
          builder: (context, provider, _) {
            // 在 builder 内动态读取，这样数据变化时会自动重绘
            final daySchedules = provider.getSchedulesByDate(day);
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 顶部拖拽提示条
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // 标题行
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${day.year}年${day.month}月${day.day}日 周${weekdayNames[day.weekday - 1]}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (isToday)
                                    const Text(
                                      '今天',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  if (holidayTitle.isNotEmpty) ...[
                                    if (isToday) const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isHoliday
                                            ? Colors.green[50]
                                            : Colors.orange[50],
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isHoliday
                                              ? Colors.green[200]!
                                              : Colors.orange[200]!,
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Text(
                                        '$holidayTitle${isHoliday ? '（放假）' : '（调休）'}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isHoliday
                                              ? Colors.green[700]
                                              : Colors.orange[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (holidayTitle.isEmpty && !isToday)
                                    Text(
                                      '共 ${daySchedules.length} 项日程',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (daySchedules.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${daySchedules.length} 项',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, size: 22),
                        ),
                      ],
                    ),
                  ),
                  // 日程列表
                  Flexible(
                    child: daySchedules.isEmpty
                        ? _buildEmptyDayState(day)
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                            shrinkWrap: true,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemCount: daySchedules.length,
                            itemBuilder: (context, index) {
                              final schedule = daySchedules[index];
                              return _buildScheduleDetailCard(schedule, day, provider);
                            },
                          ),
                  ),
                  // 添加按钮
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => AddScheduleScreen(selectedDate: day),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text(
                          '添加日程',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyDayState(DateTime day) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_available,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 14),
          Text(
            '这一天还没有安排',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '点击下方按钮开始规划吧',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleDetailCard(Schedule schedule, DateTime day, ScheduleProvider scheduleProvider) {
    final color = schedule.color != null
        ? Color(int.parse('0xFF${schedule.color!.replaceFirst('#', '')}'))
        : const Color(0xFFFFB74D);
    final isAllDay = schedule.isAllDay == 1;
    final startDateTime = DateTime.tryParse(schedule.startTime);
    final endDateTime = schedule.endTime != null
        ? DateTime.tryParse(schedule.endTime!)
        : null;
    final hasTime = !isAllDay && startDateTime != null;

    String timeText;
    if (isAllDay) {
      timeText = '全天';
    } else if (hasTime && endDateTime != null) {
      timeText =
          '${_formatTime(startDateTime)} - ${_formatTime(endDateTime)}';
    } else if (hasTime) {
      timeText = '${_formatTime(startDateTime)} 开始';
    } else {
      timeText = '';
    }

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddScheduleScreen(schedule: schedule),
          ),
        );
        if (mounted) {
          await scheduleProvider.loadSchedules(
            DateTime(day.year, day.month, 1),
            DateTime(day.year, day.month + 1, 0),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!, width: 1),
          boxShadow: [
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
                color: color,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
              ),
            ),
            // 内容
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    Text(
                      schedule.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 时间标签
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isAllDay ? Icons.event : Icons.access_time,
                                size: 14,
                                color: color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                timeText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // 备注
                    if (schedule.description != null && schedule.description!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.edit_note,
                              size: 16,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                schedule.description!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

// ===== 日期选择弹窗：支持自动滚动到当前年 =====

class _YearMonthPickerDialog extends StatefulWidget {
  final int initialYear;
  final int initialMonth;
  final int minYear;
  final int maxYear;
  final List<String> months;
  final Function(int year, int month) onConfirmed;

  const _YearMonthPickerDialog({
    required this.initialYear,
    required this.initialMonth,
    required this.minYear,
    required this.maxYear,
    required this.months,
    required this.onConfirmed,
  });

  @override
  State<_YearMonthPickerDialog> createState() => _YearMonthPickerDialogState();
}

class _YearMonthPickerDialogState extends State<_YearMonthPickerDialog> {
  late int _pickYear;
  late int _pickMonth;

  // 每行高度估算值（用于计算初始滚动位置）
  final double _rowHeight = 36.0; // Container padding + margin approx

  late ScrollController _yearScrollController;

  @override
  void initState() {
    super.initState();
    _pickYear = widget.initialYear;
    _pickMonth = widget.initialMonth;

    // 计算当前年所在的行，设置初始滚动位置
    // 两列布局：第 0 行 = [minYear, minYear + rowsPerYear]
    final totalYears = widget.maxYear - widget.minYear + 1;
    final totalRows = (totalYears / 2).ceil();

    // 当前年的行索引（如果是奇数索引，放在右侧，也在同一行）
    final yearIndex = _pickYear - widget.minYear;
    // 两列：行号 = index ~/ 2
    final currentRow = yearIndex ~/ 2;

    // 让当前年滚动到可见区域的中间位置
    // 但滚动位置不能小于 0，也不能超过列表高度
    final double maxScrollOffset =
        (totalRows * _rowHeight) - 140.0; // 140 = 可见区域高度
    double initialOffset = (currentRow * _rowHeight) - 60.0;
    if (initialOffset < 0) initialOffset = 0;
    if (initialOffset > maxScrollOffset) initialOffset = maxScrollOffset;

    _yearScrollController = ScrollController(initialScrollOffset: initialOffset);

    // 确保布局完成后再跳一次（避免渲染顺序问题）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_yearScrollController.hasClients) {
        _yearScrollController.jumpTo(initialOffset);
      }
    });
  }

  @override
  void dispose() {
    _yearScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalYears = widget.maxYear - widget.minYear + 1;
    final totalRows = (totalYears / 2).ceil();

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择日期',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // 年份
            const Text(
              '年份',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: RawScrollbar(
                controller: _yearScrollController,
                thumbColor: Colors.grey[400],
                radius: const Radius.circular(4),
                thickness: 3,
                child: SingleChildScrollView(
                  controller: _yearScrollController,
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: List.generate(totalRows, (rowIdx) {
                      final leftYear = widget.minYear + rowIdx;
                      final rightYear = widget.minYear + rowIdx + totalRows;
                      final hasRight = rightYear <= widget.maxYear;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: SizedBox(
                          height: 32,
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildYearButton(leftYear),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: hasRight
                                    ? _buildYearButton(rightYear)
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 月份（固定 4x3 网格）
            const Text(
              '月份',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                children: List.generate(3, (row) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: row < 2 ? 4 : 0),
                    child: SizedBox(
                      height: 32,
                      child: Row(
                        children: List.generate(4, (col) {
                          final m = row * 4 + col + 1;
                          return Expanded(
                            child: _buildMonthButton(m),
                          );
                        }),
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 16),

            // 按钮行
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    widget.onConfirmed(_pickYear, _pickMonth);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('确定'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearButton(int year) {
    final isSelected = year == _pickYear;
    return GestureDetector(
      onTap: () {
        setState(() {
          _pickYear = year;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '$year',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildMonthButton(int month) {
    final isSelected = month == _pickMonth;
    final label = widget.months[month - 1];
    return GestureDetector(
      onTap: () {
        setState(() {
          _pickMonth = month;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
