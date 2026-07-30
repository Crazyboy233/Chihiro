import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/transaction.dart';
import '../../providers/category_provider.dart';
import '../../services/database_service.dart';
import '../../utils/date_utils.dart' as qx;
import '../../utils/number_utils.dart';
import '../transaction/add_transaction_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  List<Transaction> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _isLoading = false;
      });
      return;
    }
    setState(() => _isLoading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(keyword);
    });
  }

  Future<void> _performSearch(String keyword) async {
    try {
      final results = await DatabaseService.instance.searchTransactions(keyword);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
          _hasSearched = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _results = [];
      _hasSearched = false;
    });
  }

  /// 按日期分组
  Map<DateTime, List<Transaction>> _groupTransactionsByDate(List<Transaction> transactions) {
    Map<DateTime, List<Transaction>> grouped = {};
    for (var transaction in transactions) {
      final date = qx.DateUtils.parseDate(transaction.date);
      final dateKey = DateTime(date.year, date.month, date.day);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(transaction);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: _buildSearchField(),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _clearSearch,
            ),
        ],
      ),
      body: Consumer<CategoryProvider>(
        builder: (context, categoryProvider, child) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!_hasSearched) {
            return _buildInitialHint();
          }

          if (_results.isEmpty) {
            return _buildEmptyResults();
          }

          final grouped = _groupTransactionsByDate(_results);
          final totalExpense = _results
              .where((t) => t.type == 'expense')
              .fold(0.0, (sum, t) => sum + t.amount);
          final totalIncome = _results
              .where((t) => t.type == 'income')
              .fold(0.0, (sum, t) => sum + t.amount);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildSummaryBar(_results.length, totalIncome, totalExpense),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final date = grouped.keys.elementAt(index);
                    final transactions = grouped[date]!;
                    return _buildDateGroup(date, transactions, categoryProvider);
                  },
                  childCount: grouped.length,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkDivider
            : AppColors.divider,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: (value) {
          _debounce?.cancel();
          final keyword = value.trim();
          if (keyword.isNotEmpty) {
            setState(() => _isLoading = true);
            _performSearch(keyword);
          }
        },
        style: TextStyle(
          fontSize: 15,
          color: AppColors.tp(context),
        ),
        decoration: InputDecoration(
          hintText: '搜索分类、分类备注、备注',
          hintStyle: TextStyle(
            fontSize: 14,
            color: AppColors.tt(context),
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 20,
            color: AppColors.tt(context),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(top: 8),
        ),
      ),
    );
  }

  Widget _buildInitialHint() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: AppColors.tt(context),
          ),
          const SizedBox(height: 16),
          Text(
            '输入关键字搜索记账记录',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.ts(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '支持搜索分类名称、分类备注、备注',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.tt(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: AppColors.tt(context),
          ),
          const SizedBox(height: 16),
          Text(
            '未找到相关记录',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.ts(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '试试其他关键字',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.tt(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(int count, double income, double expense) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            '共 $count 条记录',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.ts(context),
            ),
          ),
          const Spacer(),
          if (income > 0) ...[
            const Icon(Icons.arrow_downward, color: AppColors.income, size: 14),
            const SizedBox(width: 4),
            Text(
              '¥${NumberUtils.formatCurrency(income)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.income,
              ),
            ),
            const SizedBox(width: 12),
          ],
          if (expense > 0) ...[
            const Icon(Icons.arrow_upward, color: AppColors.expense, size: 14),
            const SizedBox(width: 4),
            Text(
              '¥${NumberUtils.formatCurrency(expense)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.expense,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateGroup(DateTime date, List<Transaction> transactions, CategoryProvider categoryProvider) {
    final dailyExpense = transactions
        .where((t) => t.type == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 4),
          child: Row(
            children: [
              Text(
                qx.DateUtils.formatDayWithWeekday(date),
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.ts(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (dailyExpense > 0)
                Text(
                  '支出 ¥${NumberUtils.formatCurrency(dailyExpense)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.ts(context).withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        ...transactions.map((transaction) {
          final category = categoryProvider.getCategoryById(transaction.categoryId);
          return _buildTransactionItem(transaction, category);
        }),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildTransactionItem(Transaction transaction, dynamic category) {
    final isIncome = transaction.type == 'income';
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddTransactionScreen(transaction: transaction),
          ),
        );
        // 编辑返回后刷新搜索结果
        if (mounted && _searchController.text.trim().isNotEmpty) {
          _performSearch(_searchController.text.trim());
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: category != null
                    ? Color(int.parse('0xFF${category.color.replaceFirst('#', '')}')).withValues(alpha: 0.1)
                    : AppColors.dv(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  category?.icon ?? '📦',
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category?.name ?? '未分类',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (transaction.categoryNote?.isNotEmpty == true ||
                      transaction.note?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        [transaction.categoryNote, transaction.note]
                            .where((e) => e?.isNotEmpty == true)
                            .join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.ts(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              '${isIncome ? '+' : '-'}¥${NumberUtils.formatCurrency(transaction.amount)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isIncome ? AppColors.income : AppColors.expense,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
