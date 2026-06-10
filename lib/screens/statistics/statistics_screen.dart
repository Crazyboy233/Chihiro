import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/category.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/database_service.dart';
import '../../utils/date_utils.dart' as qx;
import '../../utils/number_utils.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  String _type = 'expense';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TransactionProvider>().setDateRangeType('month');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('统计'),
      ),
      body: Consumer2<TransactionProvider, CategoryProvider>(
        builder: (context, transactionProvider, categoryProvider, child) {
          final summary = transactionProvider.summary;
          final categories = _type == 'income'
              ? categoryProvider.incomeCategories
              : categoryProvider.expenseCategories;

          return FutureBuilder<Map<String, double>>(
            future: _getCategorySummary(transactionProvider),
            builder: (context, snapshot) {
              final categorySummary = snapshot.data ?? {};

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTypeSelector(),
                    const SizedBox(height: 16),
                    _buildDateRangeSelector(transactionProvider),
                    const SizedBox(height: 20),
                    _buildSummaryCard(summary),
                    const SizedBox(height: 20),
                    _buildCategoryList(categories, categorySummary),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _type = 'expense';
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _type == 'expense' ? AppColors.expense : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                ),
                child: Text(
                  '支出',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _type == 'expense' ? Colors.white : AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: _type == 'expense' ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _type = 'income';
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _type == 'income' ? AppColors.income : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                ),
                child: Text(
                  '收入',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _type == 'income' ? Colors.white : AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: _type == 'income' ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector(TransactionProvider provider) {
    String title;
    switch (provider.dateRangeType) {
      case 'week':
        title = '${qx.DateUtils.formatDay(provider.currentDateRange.start)} - ${qx.DateUtils.formatDay(provider.currentDateRange.end)}';
        break;
      case 'year':
        title = '${provider.currentDate.year}年';
        break;
      case 'custom':
        title = '${qx.DateUtils.formatDay(provider.currentDateRange.start)} - ${qx.DateUtils.formatDay(provider.currentDateRange.end)}';
        break;
      case 'month':
      default:
        title = qx.DateUtils.formatMonth(provider.currentDate);
        break;
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    provider.setDateRangeType('week');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: provider.dateRangeType == 'week' ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '周',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: provider.dateRangeType == 'week' ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    provider.setDateRangeType('month');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: provider.dateRangeType == 'month' ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '月',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: provider.dateRangeType == 'month' ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    provider.setDateRangeType('year');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: provider.dateRangeType == 'year' ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '年',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: provider.dateRangeType == 'year' ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    await _showCustomDateRangePicker(provider);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: provider.dateRangeType == 'custom' ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '筛选',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: provider.dateRangeType == 'custom' ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              if (provider.dateRangeType != 'custom')
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => provider.previousPeriod(),
                ),
              if (provider.dateRangeType == 'custom')
                const SizedBox(width: 48),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (provider.dateRangeType != 'custom')
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => provider.nextPeriod(),
                ),
              if (provider.dateRangeType == 'custom')
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showCustomDateRangePicker(provider),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showCustomDateRangePicker(TransactionProvider provider) async {
    final now = qx.DateUtils.getBeijingTime();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: provider.dateRangeType == 'custom'
          ? provider.currentDateRange
          : null,
    );
    
    if (picked != null && mounted) {
      provider.setCustomDateRange(picked.start, picked.end);
    }
  }

  Widget _buildSummaryCard(Map<String, double> summary) {
    final amount = _type == 'income' ? summary['income'] : summary['expense'];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _type == 'income'
              ? [AppColors.income, const Color(0xFF0DA268)]
              : [AppColors.expense, const Color(0xFFEA580C)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            _type == 'income' ? '总收入' : '总支出',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¥${NumberUtils.formatCurrency(amount ?? 0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(List<Category> categories, Map<String, double> summary) {
    final sortedEntries = summary.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = summary.values.fold(0.0, (sum, value) => sum + value);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: sortedEntries.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = sortedEntries[index];
          Category? category;
          try {
            category = categories.firstWhere((c) => c.name == entry.key);
          } catch (e) {
            category = null;
          }
          final percentageValue = total > 0 ? (entry.value / total * 100) : 0.0;
          final percentageStr = percentageValue.toStringAsFixed(1);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: category != null
                        ? Color(int.parse('0xFF${category.color.replaceFirst('#', '')}')).withOpacity(0.1)
                        : AppColors.divider,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      category?.icon ?? '📦',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '¥${NumberUtils.formatCurrency(entry.value)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Stack(
                        children: [
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.divider,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Container(
                            width: (percentageValue / 100) * MediaQuery.of(context).size.width * 0.5,
                            height: 4,
                            decoration: BoxDecoration(
                              color: category != null
                                  ? Color(int.parse('0xFF${category.color.replaceFirst('#', '')}'))
                                  : AppColors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$percentageStr%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<Map<String, double>> _getCategorySummary(TransactionProvider provider) async {
    try {
      final range = provider.currentDateRange;
      return await DatabaseService.instance.getCategorySummary(range.start, range.end, _type);
    } catch (e) {
      return {};
    }
  }
}
