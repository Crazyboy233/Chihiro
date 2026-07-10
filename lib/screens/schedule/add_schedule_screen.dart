import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/schedule.dart';
import '../../providers/schedule_provider.dart';

class AddScheduleScreen extends StatefulWidget {
  final DateTime? selectedDate;
  final Schedule? schedule;

  const AddScheduleScreen({super.key, this.selectedDate, this.schedule});

  bool get isEditing => schedule != null;

  @override
  State<AddScheduleScreen> createState() => _AddScheduleScreenState();
}

class _AddScheduleScreenState extends State<AddScheduleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  late DateTime _selectedDate;
  late DateTime _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isAllDay = false;
  bool _isMultiDay = false;
  String? _selectedColor;

  final List<String> _availableColors = [
    '#EF4444',
    '#F97316',
    '#F59E0B',
    '#EAB308',
    '#84CC16',
    '#10B981',
    '#14B8A6',
    '#06B6D4',
    '#0EA5E9',
    '#3B82F6',
    '#6366F1',
    '#8B5CF6',
    '#A855F7',
    '#D946EF',
    '#EC4899',
    '#F43F5E',
  ];

  @override
  void initState() {
    super.initState();

    if (widget.isEditing) {
      final s = widget.schedule!;
      _titleController.text = s.title;
      _descriptionController.text = s.description ?? '';
      _selectedColor = _availableColors.contains(s.color)
          ? s.color
          : _availableColors[0];

      try {
        final start = DateTime.parse(s.startTime);
        _selectedDate = DateTime(start.year, start.month, start.day);
        _startTime = TimeOfDay(hour: start.hour, minute: start.minute);

        if (s.endTime != null && s.endTime!.isNotEmpty) {
          try {
            final e = DateTime.parse(s.endTime!);
            final endDateOnly = DateTime(e.year, e.month, e.day);
            if (endDateOnly != _selectedDate) {
              _isMultiDay = true;
              _endDate = endDateOnly;
              _isAllDay = true;
            } else {
              _endDate = _selectedDate;
              _endTime = TimeOfDay(hour: e.hour, minute: e.minute);
            }
          } catch (_) {}
        } else {
          _endDate = _selectedDate;
        }

        if (s.isAllDay == 1) {
          _isAllDay = true;
          _startTime = const TimeOfDay(hour: 9, minute: 0);
        }
      } catch (_) {
        _selectedDate = DateTime.now();
        _endDate = _selectedDate;
        _startTime = const TimeOfDay(hour: 9, minute: 0);
      }
    } else {
      _selectedDate = widget.selectedDate ?? DateTime.now();
      _endDate = _selectedDate;
      _startTime = const TimeOfDay(hour: 9, minute: 0);
      _selectedColor = _availableColors[0];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _isAllDay ? 0 : (_startTime?.hour ?? 0),
      _isAllDay ? 0 : (_startTime?.minute ?? 0),
    );

    final endDateTime = _isMultiDay
        ? DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59)
        : _endTime != null && !_isAllDay
            ? DateTime(
                _selectedDate.year,
                _selectedDate.month,
                _selectedDate.day,
                _endTime!.hour,
                _endTime!.minute,
              )
            : null;

    final schedule = Schedule(
      id: widget.schedule?.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.isNotEmpty ? _descriptionController.text.trim() : null,
      startTime: startDateTime.toIso8601String(),
      endTime: endDateTime?.toIso8601String(),
      isAllDay: (_isAllDay || _isMultiDay) ? 1 : 0,
      color: _selectedColor,
      createdAt: widget.schedule?.createdAt ?? now.toIso8601String(),
      updatedAt: now.toIso8601String(),
    );

    final provider = context.read<ScheduleProvider>();
    try {
      if (widget.isEditing) {
        await provider.updateSchedule(schedule);
      } else {
        await provider.addSchedule(schedule);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.isEditing ? '更新' : '添加'}日程失败: $e')),
      );
    }
  }

  Future<void> _delete() async {
    final provider = context.read<ScheduleProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除日程'),
        content: const Text('确定删除这个日程吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      if (widget.schedule?.id != null) {
        await provider.deleteSchedule(widget.schedule!.id!);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse('0xFF${_selectedColor!.replaceFirst('#', '')}'));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isEditing ? '编辑日程' : '添加日程',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题输入
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextFormField(
                  controller: _titleController,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: '日程标题',
                    hintStyle: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.title, size: 22),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入标题';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 14),

              // 描述输入
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: '添加备注（可选）',
                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.edit_note, size: 22),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 颜色选择
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '颜色',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableColors.map((c) {
                        final isSelected = _selectedColor == c;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedColor = c;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: isSelected ? 40 : 36,
                            height: isSelected ? 40 : 36,
                            decoration: BoxDecoration(
                              color: Color(int.parse('0xFF${c.replaceFirst('#', '')}')),
                              shape: BoxShape.circle,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Color(int.parse('0xFF${c.replaceFirst('#', '')}'))
                                            .withValues(alpha: 0.4),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                              border: isSelected
                                  ? Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    )
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 18,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 跨天开关
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.date_range, color: color, size: 20),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        '跨天',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Switch(
                      value: _isMultiDay,
                      activeTrackColor: color.withValues(alpha: 0.5),
                      activeThumbColor: color,
                      onChanged: (value) {
                        setState(() {
                          _isMultiDay = value;
                          if (value) {
                            _isAllDay = true;
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 日期选择
              if (_isMultiDay) ...[
                _buildOptionCard(
                  icon: Icons.calendar_today,
                  title: '开始日期',
                  value:
                      '${_selectedDate.year} 年 ${_selectedDate.month} 月 ${_selectedDate.day} 日',
                  valueColor: color,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      setState(() {
                        _selectedDate = date;
                        if (_endDate.isBefore(date)) {
                          _endDate = date;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                _buildOptionCard(
                  icon: Icons.calendar_today,
                  title: '结束日期',
                  value:
                      '${_endDate.year} 年 ${_endDate.month} 月 ${_endDate.day} 日',
                  valueColor: color,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _endDate,
                      firstDate: _selectedDate,
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      setState(() {
                        _endDate = date;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
              ] else ...[
                _buildOptionCard(
                  icon: Icons.calendar_today,
                  title: '日期',
                  value:
                      '${_selectedDate.year} 年 ${_selectedDate.month} 月 ${_selectedDate.day} 日',
                  valueColor: color,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      setState(() {
                        _selectedDate = date;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
              ],

              // 全天开关
              if (!_isMultiDay)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.schedule, color: color, size: 20),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          '全天',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Switch(
                        value: _isAllDay,
                        activeTrackColor: color.withValues(alpha: 0.5),
                        activeThumbColor: color,
                        onChanged: (value) {
                          setState(() {
                            _isAllDay = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              if (!_isMultiDay) const SizedBox(height: 12),

              // 时间选择
              if (!_isAllDay) ...[
                _buildOptionCard(
                  icon: Icons.access_time,
                  title: '开始时间',
                  value: _startTime?.format(context) ?? '请选择',
                  valueColor: color,
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _startTime ?? TimeOfDay.now(),
                    );
                    if (time != null) {
                      setState(() {
                        _startTime = time;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                _buildOptionCard(
                  icon: Icons.access_time,
                  title: '结束时间',
                  value: _endTime?.format(context) ?? '不设置',
                  valueColor: color,
                  showClear: _endTime != null,
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _endTime ?? TimeOfDay.now(),
                    );
                    if (time != null) {
                      setState(() {
                        _endTime = time;
                      });
                    }
                  },
                  onClear: () {
                    setState(() {
                      _endTime = null;
                    });
                  },
                ),
                const SizedBox(height: 20),
              ] else
                const SizedBox(height: 20),

              // 保存按钮
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    widget.isEditing ? '保存' : '添加',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (widget.isEditing) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _delete,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      '删除日程',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String value,
    required Color valueColor,
    required VoidCallback onTap,
    bool showClear = false,
    VoidCallback? onClear,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: valueColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: valueColor, size: 20),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: valueColor,
                  ),
                ),
              ),
              if (showClear && onClear != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onClear,
                  child: const Icon(
                    Icons.cancel_rounded,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                ),
              ],
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
