import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/habit_goal.dart';
import '../../providers/habit_provider.dart';

class AddHabitScreen extends StatefulWidget {
  final HabitGoal? goal;

  const AddHabitScreen({super.key, this.goal});

  bool get isEditing => goal != null;

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  final List<String> _availableIcons = [
    '🏃', '📚', '💧', '🧘', '🎵', '🎨', '💪', '📝', '🧠', '🎯',
    '📖', '🎮', '🎬', '🏋️', '🏊', '🚴', '🧗', '🎹', '🎸', '🏆',
  ];

  final List<String> _availableColors = [
    '#EF4444', '#F97316', '#F59E0B', '#84CC16', '#10B981', '#14B8A6',
    '#06B6D4', '#0EA5E9', '#3B82F6', '#6366F1', '#8B5CF6', '#A855F7',
    '#D946EF', '#EC4899', '#F43F5E',
  ];

  String _selectedIcon = '🎯';
  String _selectedColor = '#6366F1';
  String _selectedFrequency = 'daily';
  int _intervalDays = 2;

  // 开始日期（默认当天）
  late DateTime _startDate;
  // 截止日期（默认 null，即不设截止）
  DateTime? _endDate;

  // 自定义星期选择（仅用于 frequency == 'custom'）
  final Set<int> _selectedWeekdays = {1, 2, 3, 4, 5};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);

    // 编辑模式：回填数据
    if (widget.isEditing) {
      final g = widget.goal!;
      _nameController.text = g.name;
      _descriptionController.text = g.description ?? '';
      _selectedIcon = _availableIcons.contains(g.icon)
          ? g.icon
          : _selectedIcon;
      _selectedColor = _availableColors.contains(g.color)
          ? g.color
          : _selectedColor;
      _selectedFrequency = g.frequency;
      _intervalDays = g.customIntervalDays ?? 2;

      try {
        final s = g.startDate.split('-');
        _startDate = DateTime(int.parse(s[0]), int.parse(s[1]), int.parse(s[2]));
      } catch (_) {}

      if (g.endDate != null && g.endDate!.isNotEmpty) {
        try {
          final e = g.endDate!.split('-');
          _endDate = DateTime(int.parse(e[0]), int.parse(e[1]), int.parse(e[2]));
        } catch (_) {}
      }

      if (g.targetDays != null && g.targetDays!.isNotEmpty) {
        final list = g.targetDays!
            .split(',')
            .map((e) => int.tryParse(e))
            .whereType<int>()
            .toSet();
        if (list.isNotEmpty) {
          _selectedWeekdays.clear();
          _selectedWeekdays.addAll(list);
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // 校验：如果设了截止日期，必须 >= 开始日期
    if (_endDate != null && _endDate!.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('截止日期不能早于开始日期')),
      );
      return;
    }

    final now = DateTime.now();
    final startDateStr = _formatDate(_startDate);
    final endDateStr = _endDate != null ? _formatDate(_endDate!) : null;

    String? targetDays;
    if (_selectedFrequency == 'custom') {
      final sorted = _selectedWeekdays.toList()..sort();
      targetDays = sorted.join(',');
    }

    final baseGoal = HabitGoal(
      id: widget.goal?.id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      icon: _selectedIcon,
      color: _selectedColor,
      frequency: _selectedFrequency,
      targetDays: targetDays,
      customIntervalDays: _selectedFrequency == 'interval' ? _intervalDays : null,
      startDate: startDateStr,
      endDate: endDateStr,
      isActive: 1,
      createdAt: widget.goal?.createdAt ?? now.toIso8601String(),
      updatedAt: now.toIso8601String(),
    );

    final provider = context.read<HabitProvider>();
    try {
      if (widget.isEditing) {
        await provider.updateGoal(baseGoal);
      } else {
        await provider.addGoal(baseGoal);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.isEditing ? '更新' : '添加'}目标失败: $e')),
      );
    }
  }

  Future<void> _delete() async {
    final provider = context.read<HabitProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除目标'),
        content: const Text('确定删除这个打卡目标及其所有打卡记录吗？'),
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
      if (widget.goal?.id != null) {
        await provider.deleteGoal(widget.goal!.id!);
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
    final color = Color(int.parse('0xFF${_selectedColor.replaceFirst('#', '')}'));

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
          widget.isEditing ? '编辑打卡目标' : '新建打卡目标',
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
              // 图标 + 名称（统一在一个卡片里）
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: color.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _selectedIcon,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        controller: _nameController,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          hintText: '目标名称',
                          hintStyle: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF94A3B8),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '请输入目标名称';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 描述
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
                    hintText: '描述（可选）',
                    hintStyle: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.edit_note, size: 22),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 选择图标
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
                      '图标',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableIcons.map((icon) {
                        final isSelected = icon == _selectedIcon;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedIcon = icon;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withValues(alpha: 0.2)
                                  : const Color(0xFFF1F5F9),
                              border: Border.all(
                                color: isSelected ? color : Colors.transparent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                icon,
                                style: TextStyle(
                                  fontSize: isSelected ? 24 : 22,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 选择颜色
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
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableColors.map((c) {
                        final isSelected = c == _selectedColor;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedColor = c;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: isSelected ? 40 : 34,
                            height: isSelected ? 40 : 34,
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
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white, size: 18)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 开始日期选择
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 20,
                      color: color,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '开始日期',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_startDate.year}年${_startDate.month}月${_startDate.day}日',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime(now.year - 5, 1, 1),
                          lastDate: DateTime(now.year + 10, 12, 31),
                          locale: const Locale('zh', 'CN'),
                        );
                        if (picked != null) {
                          setState(() {
                            _startDate = DateTime(picked.year, picked.month, picked.day);
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '选择',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 截止日期
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_available,
                      size: 20,
                      color: color,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '截止日期',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _endDate == null
                              ? '不设置（长期目标）'
                              : '${_endDate!.year}年${_endDate!.month}月${_endDate!.day}日',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _endDate == null ? const Color(0xFF94A3B8) : null,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? _startDate,
                          firstDate: DateTime(_startDate.year, _startDate.month, _startDate.day),
                          lastDate: DateTime(DateTime.now().year + 10, 12, 31),
                          locale: const Locale('zh', 'CN'),
                        );
                        if (picked != null) {
                          setState(() {
                            _endDate = DateTime(picked.year, picked.month, picked.day);
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _endDate == null ? '选择' : '更改',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                    if (_endDate != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _endDate = null;
                            });
                          },
                          child: const Icon(
                            Icons.cancel_rounded,
                            color: Color(0xFF94A3B8),
                            size: 22,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 频率选择（药丸样式）
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
                      '打卡频率',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFrequencyChip('每天', 'daily'),
                        _buildFrequencyChip('工作日', 'weekdays'),
                        _buildFrequencyChip('每周', 'weekly'),
                        _buildFrequencyChip('自定义星期', 'custom'),
                        _buildFrequencyChip('每隔几天', 'interval'),
                      ],
                    ),

                    // 自定义星期选择
                    if (_selectedFrequency == 'custom') ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(7, (index) {
                          final day = index + 1;
                          final isSelected = _selectedWeekdays.contains(day);
                          const weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedWeekdays.remove(day);
                                } else {
                                  _selectedWeekdays.add(day);
                                }
                              });
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected ? color : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  weekdayNames[index],
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],

                    // 每隔几天的数值选择器
                    if (_selectedFrequency == 'interval') ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text(
                            '每隔',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (_intervalDays > 1) _intervalDays--;
                              });
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.remove, size: 20),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 60,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: color.withValues(alpha: 0.3)),
                            ),
                            child: Center(
                              child: Text(
                                '$_intervalDays',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (_intervalDays < 30) _intervalDays++;
                              });
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.add, size: 20),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            '天',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '从 ${_startDate.year}年${_startDate.month}月${_startDate.day}日 开始，每过 $_intervalDays 天打卡一次',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
                    widget.isEditing ? '保存' : '创建目标',
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
                      '删除目标',
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

  Widget _buildFrequencyChip(String label, String value) {
    final isSelected = _selectedFrequency == value;
    final color = Color(int.parse('0xFF${_selectedColor.replaceFirst('#', '')}'));
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFrequency = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
