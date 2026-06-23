import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/category.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/database_service.dart';
import '../../utils/date_utils.dart' as qx;
import '../../utils/number_utils.dart';
import 'category_detail_screen.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  String _type = 'expense';
  late final PageController _pageController;
  late DateTime _baseDate;
  static const int _initialPage = 10000;
  int _currentPage = _initialPage;
  final Map<String, Map<String, double>> _pageCache = {};

  DateTime _dateForPage(int page) {
    final delta = page - _initialPage;
    final type = context.read<TransactionProvider>().dateRangeType;
    switch (type) {
      case 'week':
        return _baseDate.add(Duration(days: 7 * delta));
      case 'year':
        return DateTime(_baseDate.year + delta, _baseDate.month);
      case 'month':
      default:
        return DateTime(_baseDate.year, _baseDate.month + delta);
    }
  }

  DateTimeRange _rangeForDate(DateTime date, String type) {
    switch (type) {
      case 'week':
        return DateTimeRange(
          start: qx.DateUtils.getStartOfWeek(date),
          end: qx.DateUtils.getEndOfWeek(date),
        );
      case 'year':
        return DateTimeRange(
          start: qx.DateUtils.getStartOfYear(date),
          end: qx.DateUtils.getEndOfYear(date),
        );
      case 'custom':
        return context.read<TransactionProvider>().currentDateRange;
      case 'month':
      default:
        return DateTimeRange(
          start: qx.DateUtils.getStartOfMonth(date),
          end: qx.DateUtils.getEndOfMonth(date),
        );
    }
  }

  String _cacheKey(int page, String type) => '${type}_$page';

  Future<Map<String, double>> _getCategorySummaryForPage(int page) async {
    final type = context.read<TransactionProvider>().dateRangeType;
    final key = _cacheKey(page, '$type$_type');
    if (_pageCache.containsKey(key)) {
      return _pageCache[key]!;
    }
    try {
      final date = _dateForPage(page);
      final range = _rangeForDate(date, type);
      final data = await DatabaseService.instance.getCategorySummary(range.start, range.end, _type);
      _pageCache[key] = data;
      return data;
    } catch (e) {
      return {};
    }
  }

  @override
  void initState() {
    super.initState();
    _baseDate = qx.DateUtils.getBeijingTime();
    _pageController = PageController(initialPage: _currentPage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TransactionProvider>().setDateRangeType('month');
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    final provider = context.read<TransactionProvider>();
    if (provider.dateRangeType == 'custom') return;
    _currentPage = page;
    final newDate = _dateForPage(page);
    provider.setDate(newDate);
  }

  void _goToPrevious() {
    final provider = context.read<TransactionProvider>();
    if (provider.dateRangeType == 'custom') return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _goToNext() {
    final provider = context.read<TransactionProvider>();
    if (provider.dateRangeType == 'custom') return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _switchRangeType(String type) {
    final provider = context.read<TransactionProvider>();
    final currentDate = provider.currentDate;
    _pageCache.clear();
    provider.setDateRangeType(type, resetToCurrent: false);
    provider.setDate(currentDate);
    _baseDate = currentDate;
    _currentPage = _initialPage;
    _pageController.jumpToPage(_initialPage);
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
          final isCustom = transactionProvider.dateRangeType == 'custom';

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTypeSelector(),
                    const SizedBox(height: 16),
                    _buildDateRangeSelector(transactionProvider),
                    const SizedBox(height: 20),
                    _buildSummaryCard(summary),
                  ],
                ),
              ),
              Expanded(
                child: isCustom
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: FutureBuilder<Map<String, double>>(
                          future: _getCategorySummaryForPage(_currentPage),
                          builder: (context, snapshot) {
                            return _buildCategoryList(
                                categories, snapshot.data ?? {}, transactionProvider);
                          },
                        ),
                      )
                    : PageView.builder(
                        controller: _pageController,
                        physics: const PageScrollPhysics(),
                        onPageChanged: _onPageChanged,
                        itemBuilder: (context, index) {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: FutureBuilder<Map<String, double>>(
                              future: _getCategorySummaryForPage(index),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const SizedBox(
                                    height: 200,
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }
                                return _buildCategoryList(
                                    categories, snapshot.data ?? {}, transactionProvider);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
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
                  _pageCache.clear();
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
                  _pageCache.clear();
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
                  onTap: () => _switchRangeType('week'),
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
                  onTap: () => _switchRangeType('month'),
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
                  onTap: () => _switchRangeType('year'),
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
                  onPressed: _goToPrevious,
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
                  onPressed: _goToNext,
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
      initialDateRange: provider.dateRangeType == 'custom' ? provider.currentDateRange : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      _pageCache.clear();
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
              color: Colors.white.withValues(alpha: 0.8),
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

  Widget _buildCategoryList(List<Category> categories, Map<String, double> summary, TransactionProvider provider) {
    final sortedEntries = summary.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = summary.values.fold(0.0, (sum, value) => sum + value);

    if (sortedEntries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.inbox_outlined, size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text(
                '这个日期范围内没有记录',
                style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedEntries.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final entry = sortedEntries[index];
        Category? category;
        try {
          category = categories.firstWhere((c) => c.name == entry.key);
        } catch (e) {
          category = null;
        }
        final categoryColor = category != null
            ? Color(int.parse('0xFF${category.color.replaceFirst('#', '')}'))
            : AppColors.primary;
        final percentageValue = total > 0 ? (entry.value / total * 100) : 0.0;
        final percentageStr = percentageValue.toStringAsFixed(1);

        return GestureDetector(
          onTap: () {
            if (category != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategoryDetailScreen(
                    category: category!,
                    type: _type,
                    dateRangeStart: provider.currentDateRange.start,
                    dateRangeEnd: provider.currentDateRange.end,
                  ),
                ),
              );
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      category?.icon ?? '📦',
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
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
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '¥${NumberUtils.formatCurrency(entry.value)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: AppColors.divider,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final maxWidth = constraints.maxWidth;
                                    final width = (percentageValue / 100) * maxWidth;
                                    return Container(
                                      width: width,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: categoryColor,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$percentageStr%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
