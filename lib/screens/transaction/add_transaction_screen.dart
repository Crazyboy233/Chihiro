import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/transaction.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/date_utils.dart' as qx;

class AddTransactionScreen extends StatefulWidget {
  final Transaction? transaction;

  const AddTransactionScreen({super.key, this.transaction});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  late String _type;
  int? _selectedCategoryId;
  final _amountController = TextEditingController();
  final _categoryNoteController = TextEditingController();
  final _noteController = TextEditingController();
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      // 编辑模式：初始化现有数据
      _type = widget.transaction!.type;
      _amountController.text = widget.transaction!.amount.toString();
      _categoryNoteController.text = widget.transaction!.categoryNote ?? '';
      _noteController.text = widget.transaction!.note ?? '';
      _selectedDate = DateTime.parse(widget.transaction!.date);
      _selectedCategoryId = widget.transaction!.categoryId;
    } else {
      // 新增模式
      _type = 'expense';
      _selectedDate = qx.DateUtils.getBeijingTime();
      Future.microtask(() {
        final categories = context.read<CategoryProvider>().expenseCategories;
        if (categories.isNotEmpty) {
          setState(() {
            _selectedCategoryId = categories.first.id;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _categoryNoteController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.transaction != null ? '编辑账单' : '记一笔'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        },
        child: Consumer<CategoryProvider>(
          builder: (context, categoryProvider, child) {
            final categories = _type == 'income'
                ? categoryProvider.incomeCategories
                : categoryProvider.expenseCategories;
            
            debugPrint('Showing ${categories.length} categories for $_type');
            
            if (categoryProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (categories.isEmpty) {
              return const Center(
                child: Text('没有可用的分类'),
              );
            }

            if (_selectedCategoryId == null ||
                !categories.any((category) => category.id == _selectedCategoryId)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _selectedCategoryId = categories.first.id;
                  });
                }
              });
            }

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTypeButton('支出', 'expense'),
                      const SizedBox(width: 16),
                      _buildTypeButton('收入', 'income'),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      hintStyle: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textTertiary,
                      ),
                      border: InputBorder.none,
                      prefixText: '¥',
                      prefixStyle: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 0.9,
                            ),
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final category = categories[index];
                              final isSelected = category.id == _selectedCategoryId;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedCategoryId = category.id;
                                  });
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Color(int.parse('0xFF${category.color.replaceFirst('#', '')}')).withOpacity(0.1)
                                        : AppColors.background,
                                    borderRadius: BorderRadius.circular(10),
                                    border: isSelected
                                        ? Border.all(
                                            color: Color(int.parse('0xFF${category.color.replaceFirst('#', '')}')),
                                            width: 2,
                                          )
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        category.icon,
                                        style: const TextStyle(fontSize: 22),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        category.name,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const Divider(),
                        const SizedBox(height: 10),
                        _buildFormField(
                          icon: Icons.label_outlined,
                          hint: '分类备注',
                          controller: _categoryNoteController,
                        ),
                        const SizedBox(height: 10),
                        _buildFormField(
                          icon: Icons.calendar_today_outlined,
                          hint: qx.DateUtils.formatDate(_selectedDate),
                          onTap: () => _selectDate(),
                          readOnly: true,
                        ),
                        const SizedBox(height: 10),
                        _buildFormField(
                          icon: Icons.edit_outlined,
                          hint: '备注',
                          controller: _noteController,
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: _saveTransaction,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '保存',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTypeButton(String label, String type) {
    final isSelected = _type == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _type = type;
          final categories = _type == 'income'
              ? context.read<CategoryProvider>().incomeCategories
              : context.read<CategoryProvider>().expenseCategories;
          if (categories.isNotEmpty) {
            _selectedCategoryId = categories.first.id;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (_type == 'income' ? AppColors.income : AppColors.expense).withOpacity(0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? (_type == 'income' ? AppColors.income : AppColors.expense)
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required IconData icon,
    required String hint,
    TextEditingController? controller,
    VoidCallback? onTap,
    bool readOnly = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textTertiary),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            onTap: onTap,
            readOnly: readOnly,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: AppColors.textTertiary,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: qx.DateUtils.getBeijingTime(),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveTransaction() async {
    // 先隐藏之前的提示
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择分类')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效金额')),
      );
      return;
    }

    if (widget.transaction != null) {
      // 编辑模式
      final updatedTransaction = widget.transaction!.copyWith(
        type: _type,
        categoryId: _selectedCategoryId!,
        amount: amount,
        date: _selectedDate.toIso8601String().split('T').first,
        categoryNote: _categoryNoteController.text,
        note: _noteController.text,
        updatedAt: qx.DateUtils.getCurrentTimestamp(),
      );
      await context.read<TransactionProvider>().updateTransaction(updatedTransaction);
    } else {
      // 新增模式
      final transaction = Transaction(
        type: _type,
        categoryId: _selectedCategoryId!,
        amount: amount,
        date: _selectedDate.toIso8601String().split('T').first,
        categoryNote: _categoryNoteController.text,
        note: _noteController.text,
        createdAt: qx.DateUtils.getCurrentTimestamp(),
        updatedAt: qx.DateUtils.getCurrentTimestamp(),
      );
      await context.read<TransactionProvider>().addTransaction(transaction);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }
}
