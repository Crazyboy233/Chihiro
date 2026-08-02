import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/countdown_day.dart';
import '../../providers/countdown_provider.dart';

class AddCountdownScreen extends StatefulWidget {
  final CountdownDay? day;

  const AddCountdownScreen({super.key, this.day});

  bool get isEditing => day != null;

  @override
  State<AddCountdownScreen> createState() => _AddCountdownScreenState();
}

class _AddCountdownScreenState extends State<AddCountdownScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  late DateTime _selectedDate;
  String _type = CountdownDay.typeCountdown;
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
      final d = widget.day!;
      _titleController.text = d.title;
      _noteController.text = d.note ?? '';
      _type = d.type;
      _selectedColor =
          _availableColors.contains(d.color) ? d.color : _availableColors[0];
      try {
        _selectedDate = DateTime.parse(d.targetDate);
      } catch (_) {
        _selectedDate = DateTime.now();
      }
    } else {
      _selectedDate = DateTime.now();
      _selectedColor = _availableColors[10]; // 默认主题紫
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String get _dateStr {
    final y = _selectedDate.year.toString().padLeft(4, '0');
    final m = _selectedDate.month.toString().padLeft(2, '0');
    final d = _selectedDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year + 30),
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        // 贴心默认值：选过去的日子自动切到"正数"，选今天/未来切回"倒数"
        final today = DateTime(now.year, now.month, now.day);
        final pickedDay = DateTime(picked.year, picked.month, picked.day);
        _type = pickedDay.isBefore(today)
            ? CountdownDay.typeCountup
            : CountdownDay.typeCountdown;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now().toIso8601String();
    final day = CountdownDay(
      id: widget.day?.id,
      title: _titleController.text.trim(),
      targetDate: _dateStr,
      type: _type,
      color: _selectedColor,
      note: _noteController.text.isNotEmpty ? _noteController.text.trim() : null,
      createdAt: widget.day?.createdAt ?? now,
      updatedAt: now,
    );

    final provider = context.read<CountdownProvider>();
    try {
      if (widget.isEditing) {
        await provider.updateCountdownDay(day);
      } else {
        await provider.addCountdownDay(day);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.isEditing ? '更新' : '添加'}失败: $e')),
      );
    }
  }

  Future<void> _delete() async {
    final provider = context.read<CountdownProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除倒数日'),
        content: const Text('确定删除这个倒数日吗？'),
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
      if (widget.day?.id != null) {
        await provider.deleteCountdownDay(widget.day!.id!);
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
    final color =
        Color(int.parse('0xFF${_selectedColor!.replaceFirst('#', '')}'));

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isEditing ? '编辑倒数日' : '添加倒数日',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
              onPressed: _delete,
            ),
        ],
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextFormField(
                  controller: _titleController,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: '倒数日标题，如「考试」「结婚纪念日」',
                    hintStyle: TextStyle(
                      fontSize: 16,
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

              // 类型选择：倒数 / 正数
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '类型',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTypeOption(
                            type: CountdownDay.typeCountdown,
                            icon: Icons.hourglass_top_rounded,
                            title: '倒数',
                            subtitle: '还有多久到那天',
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTypeOption(
                            type: CountdownDay.typeCountup,
                            icon: Icons.trending_up_rounded,
                            title: '正数',
                            subtitle: '已坚持 N 天',
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 日期选择
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
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
                        child: Icon(Icons.calendar_today,
                            color: color, size: 18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _type == CountdownDay.typeCountup ? '起始日' : '目标日',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${_selectedDate.year} 年 ${_selectedDate.month} 月 ${_selectedDate.day} 日',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right,
                          color: AppColors.ts(context), size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 颜色选择
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
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
                              color: Color(int.parse(
                                  '0xFF${c.replaceFirst('#', '')}')),
                              shape: BoxShape.circle,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Color(int.parse(
                                                '0xFF${c.replaceFirst('#', '')}'))
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
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 18)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 备注
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: '添加备注（可选）',
                    hintStyle:
                        TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.edit_note, size: 22),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 保存按钮
              SizedBox(
                width: double.infinity,
                height: 50,
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
                    widget.isEditing ? '保存修改' : '添加倒数日',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeOption({
    required String type,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final isSelected = _type == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _type = type;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.bd(context),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: isSelected ? color : AppColors.ts(context)),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? color
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.ts(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
