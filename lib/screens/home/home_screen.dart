import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/date_utils.dart' as qx;
import '../../utils/number_utils.dart';
import '../transaction/add_transaction_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? _activeSlidableId;

  void _setActiveSlidable(int? id) {
    setState(() {
      _activeSlidableId = id;
    });
  }

  @override
  void initState() {
    super.initState();
    // 确保初始化时重置到当月
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
        title: const Text('Chihiro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_outlined),
            onPressed: () {
              _showFilterDialog(context);
            },
          ),
        ],
      ),
      body: Consumer2<TransactionProvider, CategoryProvider>(
        builder: (context, transactionProvider, categoryProvider, child) {
          if (categoryProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final groupedTransactions = _groupTransactionsByDate(transactionProvider.transactions);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildSummaryCard(transactionProvider.summary),
              ),
              SliverToBoxAdapter(
                child: _buildDateSelector(transactionProvider),
              ),
              if (transactionProvider.transactions.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: AppColors.textTertiary,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '暂无记录',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final date = groupedTransactions.keys.elementAt(index);
                    final transactions = groupedTransactions[date]!;
                    return _buildDateGroup(date, transactions, categoryProvider, transactionProvider);
                  },
                  childCount: groupedTransactions.length,
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Map<DateTime, List<dynamic>> _groupTransactionsByDate(List<dynamic> transactions) {
    Map<DateTime, List<dynamic>> grouped = {};
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

  Widget _buildDateGroup(DateTime date, List<dynamic> transactions, CategoryProvider categoryProvider, TransactionProvider transactionProvider) {
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
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (dailyExpense > 0)
                Text(
                  '支出 ¥${NumberUtils.formatCurrency(dailyExpense)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        ...transactions.map((transaction) {
          final category = categoryProvider.getCategoryById(transaction.categoryId);
          return _buildTransactionItem(transaction, category, transactionProvider);
        }),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildSummaryCard(Map<String, double> summary) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '结余',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '¥${NumberUtils.formatCurrency(summary['balance'] ?? 0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.arrow_downward, color: AppColors.income, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '收入',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '¥${NumberUtils.formatCurrency(summary['income'] ?? 0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Icon(Icons.arrow_upward, color: AppColors.expense, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '支出',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '¥${NumberUtils.formatCurrency(summary['expense'] ?? 0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(TransactionProvider provider) {
    String title;
    switch (provider.dateRangeType) {
      case 'week':
        title = '${qx.DateUtils.formatDay(provider.currentDateRange.start)} - ${qx.DateUtils.formatDay(provider.currentDateRange.end)}';
        break;
      case 'year':
        title = '${provider.currentDate.year}年';
        break;
      case 'month':
      default:
        title = qx.DateUtils.formatMonth(provider.currentDate);
        break;
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => provider.setDateRangeType('week'),
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
                  onTap: () => provider.setDateRangeType('month'),
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
                  onTap: () => provider.setDateRangeType('year'),
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
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => provider.previousPeriod(),
              ),
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
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => provider.nextPeriod(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionItem(dynamic transaction, dynamic category, TransactionProvider transactionProvider) {
    return _SlidableTransactionItem(
      key: ValueKey('transaction_${transaction.id}'),
      transaction: transaction,
      category: category,
      isActive: _activeSlidableId == transaction.id,
      onSlidStateChange: (isSlid) {
        _setActiveSlidable(isSlid ? transaction.id : null);
      },
      onDelete: () {
        _setActiveSlidable(null);
        if (transaction.id != null) {
          transactionProvider.deleteTransaction(transaction.id!);
        }
      },
      onEdit: () {
        _setActiveSlidable(null);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddTransactionScreen(transaction: transaction),
          ),
        );
      },
    );
  }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const FilterDialog(),
    );
  }
}

class FilterDialog extends StatelessWidget {
  const FilterDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<TransactionProvider, CategoryProvider>(
      builder: (context, transactionProvider, categoryProvider, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '筛选',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              const Text('分类'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('全部'),
                    selected: transactionProvider.selectedCategoryId == null,
                    onSelected: (selected) {
                      if (selected) {
                        transactionProvider.setFilter(categoryId: null);
                      }
                    },
                  ),
                  ...categoryProvider.expenseCategories.map((category) {
                    return FilterChip(
                      label: Text(category.name),
                      selected: transactionProvider.selectedCategoryId == category.id,
                      onSelected: (selected) {
                        if (selected) {
                          transactionProvider.setFilter(categoryId: category.id);
                        }
                      },
                    );
                  }),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('确定'),
              ),
              TextButton(
                onPressed: () {
                  transactionProvider.clearFilter();
                  Navigator.pop(context);
                },
                child: const Text('重置'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SlidableTransactionItem extends StatefulWidget {
  final dynamic transaction;
  final dynamic category;
  final bool isActive;
  final ValueChanged<bool> onSlidStateChange;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _SlidableTransactionItem({
    super.key,
    required this.transaction,
    required this.category,
    required this.isActive,
    required this.onSlidStateChange,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<_SlidableTransactionItem> createState() => _SlidableTransactionItemState();
}

class _SlidableTransactionItemState extends State<_SlidableTransactionItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  bool _isSlid = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.25, 0.0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    if (widget.isActive && !_isSlid) {
      _isSlid = true;
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(_SlidableTransactionItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transaction.id != widget.transaction.id) {
      if (_isSlid) {
        _isSlid = false;
        _controller.value = 0.0;
      }
    }
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive && !_isSlid) {
        setState(() {
          _isSlid = true;
          _controller.forward();
        });
      } else if (!widget.isActive && _isSlid) {
        setState(() {
          _isSlid = false;
          _controller.reverse();
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleSlide() {
    setState(() {
      _isSlid = !_isSlid;
      if (_isSlid) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
      widget.onSlidStateChange(_isSlid);
    });
  }

  void _closeSlide() {
    if (_isSlid) {
      setState(() {
        _isSlid = false;
        _controller.reverse();
        widget.onSlidStateChange(false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = widget.transaction.type == 'income';
    return GestureDetector(
      onTap: () {
        if (_isSlid) {
          _closeSlide();
        } else {
          widget.onEdit();
        }
      },
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < 0 && !_isSlid) {
            _toggleSlide();
          } else if (details.primaryVelocity! > 0 && _isSlid) {
            _closeSlide();
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Stack(
          children: [
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_isSlid) {
                          widget.onEdit();
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(left: 20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.edit, color: Colors.white, size: 28),
                                SizedBox(height: 4),
                                Text(
                                  '编辑',
                                  style: TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_isSlid) {
                          widget.onDelete();
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: EdgeInsets.only(right: 20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.delete, color: Colors.white, size: 28),
                                SizedBox(height: 4),
                                Text(
                                  '删除',
                                  style: TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SlideTransition(
              position: _slideAnimation,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: widget.category != null
                            ? Color(int.parse('0xFF${widget.category.color.replaceFirst('#', '')}')).withValues(alpha: 0.1)
                            : AppColors.divider,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          widget.category?.icon ?? '📦',
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
                            widget.category?.name ?? '未分类',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (widget.transaction.categoryNote?.isNotEmpty == true || widget.transaction.note?.isNotEmpty == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                [widget.transaction.categoryNote, widget.transaction.note]
                                    .where((e) => e?.isNotEmpty == true)
                                    .join(' · '),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${isIncome ? '+' : '-'}¥${NumberUtils.formatCurrency(widget.transaction.amount)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isIncome ? AppColors.income : AppColors.expense,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
