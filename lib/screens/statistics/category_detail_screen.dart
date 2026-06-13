import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../models/category.dart';
import '../../services/database_service.dart';
import '../../utils/number_utils.dart';

class CategoryDetailScreen extends StatefulWidget {
  final Category category;
  final String type;
  final DateTime dateRangeStart;
  final DateTime dateRangeEnd;

  const CategoryDetailScreen({
    super.key,
    required this.category,
    required this.type,
    required this.dateRangeStart,
    required this.dateRangeEnd,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final categoryColor = Color(
      int.parse('0xFF${widget.category.color.replaceFirst('#', '')}'),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.category.name),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadTransactions(),
        builder: (context, snapshot) {
          final transactions = snapshot.data ?? [];
          final totalAmount = transactions.fold<double>(
            0,
            (sum, t) => sum + (t['amount'] as double),
          );

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              _buildHeader(totalAmount, transactions.length, categoryColor),
              const SizedBox(height: 8),
              Expanded(
                child: transactions.isEmpty
                    ? _buildEmptyState()
                    : _buildTransactionList(transactions, categoryColor),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(double totalAmount, int count, Color categoryColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(widget.category.icon, style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.category.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '共 $count 笔记录',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥${NumberUtils.formatCurrency(totalAmount)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: categoryColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.type == 'income' ? '收入' : '支出',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            '所选日期范围内没有记录',
            style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(List<Map<String, dynamic>> transactions, Color categoryColor) {
    // 按日期分组
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final t in transactions) {
      final date = t['date'] as String;
      grouped.putIfAbsent(date, () => []).add(t);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final dayList = grouped[date]!;
        final dayTotal = dayList.fold<double>(0, (sum, t) => sum + (t['amount'] as double));

        return _buildDaySection(date, dayList, dayTotal, categoryColor);
      },
    );
  }

  Widget _buildDaySection(
    String date,
    List<Map<String, dynamic>> dayList,
    double dayTotal,
    Color categoryColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 日期标题
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDateLabel(date),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '¥${NumberUtils.formatCurrency(dayTotal)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: categoryColor,
                  ),
                ),
              ],
            ),
          ),
          // 当日每笔记录
          ...dayList.asMap().entries.map((entry) {
            final tx = entry.value;
            final note = tx['note'] as String?;
            final lastOfDay = entry.key == dayList.length - 1;

            return Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, lastOfDay ? 16 : 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (note != null && note.isNotEmpty)
                          Text(
                            note,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                          )
                        else
                          const Text(
                            '无备注',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(tx['created_at'] as String?),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '¥${NumberUtils.formatCurrency(tx['amount'] as double)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatDateLabel(String dateStr) {
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return dateStr;
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${dt.month}月${dt.day}日 ${weekdays[dt.weekday - 1]}';
  }

  String _formatTime(String? createdAt) {
    if (createdAt == null || !createdAt.contains('T')) return '';
    try {
      final parts = createdAt.split('T');
      if (parts.length < 2) return '';
      final timePart = parts[1].split(':');
      if (timePart.length < 2) return '';
      return '${timePart[0]}:${timePart[1]}';
    } catch (_) {
      return '';
    }
  }

  Future<List<Map<String, dynamic>>> _loadTransactions() async {
    final all = await DatabaseService.instance.getTransactions(
      startDate: widget.dateRangeStart,
      endDate: widget.dateRangeEnd,
      categoryId: widget.category.id,
    );
    // 过滤成当前类型（expense/income）
    final filtered = all.where((t) => t.type == widget.type);
    return filtered.map((t) {
      return {
        'id': t.id,
        'date': t.date,
        'amount': t.amount,
        'note': t.note ?? t.categoryNote ?? '',
        'created_at': t.createdAt,
      };
    }).toList();
  }
}
