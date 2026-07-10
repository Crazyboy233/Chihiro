import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
  int _touchedIndex = -1;
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
                    _buildSummaryCard(summary, categories),
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

  Widget _buildSummaryCard(Map<String, double> summary, List<Category> categories) {
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
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
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
          Positioned(
            right: 0,
            top: 0,
            child: GestureDetector(
              onTap: () => _showPieChartSheet(categories),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.pie_chart_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ),
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

  void _showPieChartSheet(List<Category> categories) {
    _touchedIndex = -1;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return FutureBuilder<Map<String, double>>(
          future: _getCategorySummaryForPage(_currentPage),
          builder: (context, snapshot) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _type == 'income' ? '收入构成' : '支出构成',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textSecondary),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SizedBox(
                      height: 400,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (!snapshot.hasData || snapshot.data!.isEmpty)
                    const SizedBox(
                      height: 400,
                      child: Center(
                        child: Text(
                          '这个日期范围内没有记录',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 20),
                      child: _buildPieChartContent(categories, snapshot.data!),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPieChartContent(List<Category> categories, Map<String, double> summary) {
    final sortedEntries = summary.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = summary.values.fold(0.0, (sum, value) => sum + value);
    if (total <= 0) return const SizedBox.shrink();

    const double lineWidth = 1.2;
    const double dotRadius = 3.0;
    const double minRadialT = 10.0;
    const double popOffset = 8.0;
    const double labelSpacing = 22.0;
    const double textGap = 5.0;
    const double edgeMargin = 8.0;
    const double horizontalAngleThreshold = 0.18;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final chartH = math.min(w * 0.95, 350.0);
        final cy = chartH / 2;

        final entries = <_PieEntry>[];
        double currentAngle = -90;

        for (int i = 0; i < sortedEntries.length; i++) {
          final entry = sortedEntries[i];
          Category? category;
          try {
            category = categories.firstWhere((c) => c.name == entry.key);
          } catch (e) {
            category = null;
          }
          final categoryColor = category != null
              ? Color(int.parse('0xFF${category.color.replaceFirst('#', '')}'))
              : AppColors.primary;
          final sweepAngle = entry.value / total * 360;
          final centerAngle = currentAngle + sweepAngle / 2;
          final angleRad = centerAngle * math.pi / 180;
          final isRight = math.cos(angleRad) >= 0;
          final percentage = entry.value / total * 100;

          entries.add(_PieEntry(
            name: entry.key,
            amount: entry.value,
            percentage: percentage,
            color: categoryColor,
            angleRad: angleRad,
            isRight: isRight,
            index: i,
          ));

          currentAngle += sweepAngle;
        }

        const textStyle = TextStyle(
          fontSize: 12,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        );

        final tp = TextPainter(textDirection: TextDirection.ltr);
        double measureTextW(String text) {
          tp.text = TextSpan(text: text, style: textStyle);
          tp.layout();
          return tp.width;
        }

        double maxTextW = 0;
        for (final e in entries) {
          final tw = measureTextW('${e.name} ${e.percentage.toStringAsFixed(0)}%');
          if (tw > maxTextW) maxTextW = tw;
        }

        final dotColX = w / 2 - edgeMargin - dotRadius - textGap - maxTextW;
        final extendedEntries = entries.where((e) => math.sin(e.angleRad).abs() >= horizontalAngleThreshold).toList();
        final nearHorizEntries = entries.where((e) => math.sin(e.angleRad).abs() < horizontalAngleThreshold).toList();
        double maxExtendedCos = 0.3;
        for (final e in extendedEntries) {
          final c = math.cos(e.angleRad).abs();
          if (c > maxExtendedCos) maxExtendedCos = c;
        }
        double maxNearHorizCos = 0.0;
        for (final e in nearHorizEntries) {
          final c = math.cos(e.angleRad).abs();
          if (c > maxNearHorizCos) maxNearHorizCos = c;
        }
        const minHorizForNear = 10.0;
        final maxRByExtended = (dotColX - 24) / maxExtendedCos;
        final maxRByNearHoriz = maxNearHorizCos > 0
            ? (dotColX - minHorizForNear) / maxNearHorizCos - minRadialT - popOffset
            : double.infinity;
        final extendBuffer = (entries.length / 2).ceil() * labelSpacing * 0.7;
        final maxR = math.min(
          math.min(maxRByExtended, maxRByNearHoriz),
          cy - edgeMargin - popOffset - extendBuffer,
        );
        final outerRadius = math.max(maxR, 55.0);
        final centerRadius = outerRadius * 0.55;
        final sectionRadius = outerRadius - centerRadius;

        double minRFor(_PieEntry e) {
          final isTouched = e.index == _touchedIndex;
          return (isTouched ? outerRadius + popOffset : outerRadius) + minRadialT;
        }

        for (final e in entries) {
          e.dotX = e.isRight ? dotColX : -dotColX;
        }

        final rightEntries = entries.where((e) => e.isRight).toList();
        final leftEntries = entries.where((e) => !e.isRight).toList();

        void positionLabels(List<_PieEntry> side) {
          final topLimit = -cy + edgeMargin + 16.0;
          final bottomLimit = cy - edgeMargin - 16.0;

          final upper = <_PieEntry>[];
          final lower = <_PieEntry>[];

          for (final e in side) {
            final sinA = math.sin(e.angleRad);
            final mr = minRFor(e);
            e.naturalY = mr * sinA;
            if (sinA.abs() < horizontalAngleThreshold) {
              e.adjustedY = e.naturalY.clamp(topLimit, bottomLimit);
            } else if (sinA < 0) {
              e.adjustedY = e.naturalY;
              upper.add(e);
            } else {
              e.adjustedY = e.naturalY;
              lower.add(e);
            }
          }

          upper.sort((a, b) => b.naturalY.compareTo(a.naturalY));
          for (int i = 1; i < upper.length; i++) {
            final prev = upper[i - 1];
            final cur = upper[i];
            final target = math.min(prev.adjustedY! - labelSpacing, cur.adjustedY!);
            cur.adjustedY = target.clamp(topLimit, bottomLimit);
          }

          lower.sort((a, b) => a.naturalY.compareTo(b.naturalY));
          for (int i = 1; i < lower.length; i++) {
            final prev = lower[i - 1];
            final cur = lower[i];
            final target = math.max(prev.adjustedY! + labelSpacing, cur.adjustedY!);
            cur.adjustedY = target.clamp(topLimit, bottomLimit);
          }

          for (int pass = 0; pass < 6; pass++) {
            bool changed = false;
            upper.sort((a, b) => a.adjustedY!.compareTo(b.adjustedY!));
            for (int i = upper.length - 2; i >= 0; i--) {
              final cur = upper[i];
              final next = upper[i + 1];
              final maxY = next.adjustedY! - labelSpacing;
              if (cur.adjustedY! > maxY) {
                cur.adjustedY = maxY.clamp(topLimit, bottomLimit);
                changed = true;
              }
            }
            lower.sort((a, b) => a.adjustedY!.compareTo(b.adjustedY!));
            for (int i = 1; i < lower.length; i++) {
              final prev = lower[i - 1];
              final cur = lower[i];
              final minY = prev.adjustedY! + labelSpacing;
              if (cur.adjustedY! < minY) {
                cur.adjustedY = minY.clamp(topLimit, bottomLimit);
                changed = true;
              }
            }
            if (!changed) break;
          }
        }

        positionLabels(rightEntries);
        positionLabels(leftEntries);

        for (final e in entries) {
          final isTouched = e.index == _touchedIndex;
          final touchOuterR = isTouched ? outerRadius + popOffset : outerRadius;
          final sinA = math.sin(e.angleRad);
          final cosA = math.cos(e.angleRad);
          e.startX = touchOuterR * cosA;
          e.startY = touchOuterR * sinA;

          final dy = e.adjustedY!;
          if (sinA.abs() < horizontalAngleThreshold) {
            final r = touchOuterR + minRadialT;
            e.elbowX = r * cosA;
            e.elbowY = r * sinA;
          } else {
            final maxRForX = cosA.abs() > 0.01 ? (dotColX - 6) / cosA.abs() : double.infinity;
            final r = (dy / sinA).clamp(touchOuterR + minRadialT, maxRForX);
            e.elbowX = r * cosA;
            e.elbowY = r * sinA;
          }
        }

        final sections = <PieChartSectionData>[];
        final labels = <_PieLabelData>[];

        for (final e in entries) {
          final isTouched = e.index == _touchedIndex;
          final radius = isTouched ? sectionRadius + popOffset : sectionRadius;
          final showTitle = e.percentage >= 5.0;
          final titleFontSize = e.percentage >= 15.0 ? 12.0 : (e.percentage >= 8.0 ? 11.0 : 10.0);

          sections.add(
            PieChartSectionData(
              value: e.amount,
              color: e.color,
              title: showTitle ? '${e.percentage.toStringAsFixed(0)}%' : '',
              radius: radius,
              titleStyle: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                shadows: const [
                  Shadow(
                    blurRadius: 2,
                    color: Color(0x66000000),
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              titlePositionPercentageOffset: 0.55,
            ),
          );

          labels.add(_PieLabelData(
            text: '${e.name} ${e.percentage.toStringAsFixed(0)}%',
            color: e.color,
            startX: e.startX,
            startY: e.startY,
            elbowX: e.elbowX,
            elbowY: e.elbowY,
            dotX: e.dotX,
            dotY: e.adjustedY!,
            isRight: e.isRight,
          ));
        }

        return SizedBox(
          height: chartH,
          width: w,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: centerRadius,
                  startDegreeOffset: -90,
                  borderData: FlBorderData(show: false),
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (event is FlTapUpEvent) {
                        final touchedSection = response?.touchedSection;
                        final newIndex = touchedSection?.touchedSectionIndex ?? -1;
                        setState(() {
                          _touchedIndex = (_touchedIndex == newIndex) ? -1 : newIndex;
                        });
                      }
                    },
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _type == 'income' ? '总收入' : '总支出',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '¥${NumberUtils.formatCurrency(total)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _PieLeaderPainter(
                    labels: labels,
                    lineWidth: lineWidth,
                    dotRadius: dotRadius,
                    textGap: textGap,
                    textStyle: textStyle,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PieEntry {
  final String name;
  final double amount;
  final double percentage;
  final Color color;
  final double angleRad;
  final bool isRight;
  final int index;
  double startX = 0;
  double startY = 0;
  double elbowX = 0;
  double elbowY = 0;
  double naturalY = 0;
  double dotX = 0;
  double? adjustedY;

  _PieEntry({
    required this.name,
    required this.amount,
    required this.percentage,
    required this.color,
    required this.angleRad,
    required this.isRight,
    required this.index,
  });
}

class _PieLabelData {
  final String text;
  final Color color;
  final double startX;
  final double startY;
  final double elbowX;
  final double elbowY;
  final double dotX;
  final double dotY;
  final bool isRight;

  _PieLabelData({
    required this.text,
    required this.color,
    required this.startX,
    required this.startY,
    required this.elbowX,
    required this.elbowY,
    required this.dotX,
    required this.dotY,
    required this.isRight,
  });
}

class _PieLeaderPainter extends CustomPainter {
  final List<_PieLabelData> labels;
  final double lineWidth;
  final double dotRadius;
  final double textGap;
  final TextStyle textStyle;

  _PieLeaderPainter({
    required this.labels,
    required this.lineWidth,
    required this.dotRadius,
    required this.textGap,
    required this.textStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    for (final label in labels) {
      final paint = Paint()
        ..color = label.color
        ..strokeWidth = lineWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final dotPaint = Paint()
        ..color = label.color
        ..style = PaintingStyle.fill;

      final start = Offset(cx + label.startX, cy + label.startY);
      final elbow = Offset(cx + label.elbowX, cy + label.elbowY);
      final dot = Offset(cx + label.dotX, cy + label.dotY);

      canvas.drawLine(start, elbow, paint);
      canvas.drawLine(elbow, dot, paint);

      canvas.drawCircle(dot, dotRadius, dotPaint);

      final textPainter = TextPainter(
        text: TextSpan(text: label.text, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      final double textX;
      if (label.isRight) {
        textX = dot.dx + textGap;
      } else {
        textX = dot.dx - textGap - textPainter.width;
      }
      final textY = dot.dy - textPainter.height / 2;

      textPainter.paint(canvas, Offset(textX, textY));
    }
  }

  @override
  bool shouldRepaint(covariant _PieLeaderPainter oldDelegate) =>
      labels != oldDelegate.labels;
}
