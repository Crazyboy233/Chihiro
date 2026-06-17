import 'package:flutter/foundation.dart' hide Category;
import '../models/category.dart';
import '../services/database_service.dart';

class CategoryProvider extends ChangeNotifier {
  List<Category> _incomeCategories = [];
  List<Category> _expenseCategories = [];
  bool _isLoading = false;

  List<Category> get incomeCategories => _incomeCategories;
  List<Category> get expenseCategories => _expenseCategories;
  bool get isLoading => _isLoading;

  Future<void> loadCategories() async {
    _isLoading = true;
    notifyListeners();

    try {
      _incomeCategories = await DatabaseService.instance.getCategories('income');
      _expenseCategories = await DatabaseService.instance.getCategories('expense');
      debugPrint('Loaded ${_incomeCategories.length} income categories and ${_expenseCategories.length} expense categories');
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addCategory(Category category) async {
    await DatabaseService.instance.insertCategory(category);
    await loadCategories();
  }

  Future<void> updateCategory(Category category) async {
    await DatabaseService.instance.updateCategory(category);
    await loadCategories();
  }

  Future<void> deleteCategory(int id) async {
    await DatabaseService.instance.deleteCategory(id);
    await loadCategories();
  }

  Category? getCategoryById(int id) {
    final all = [..._incomeCategories, ..._expenseCategories];
    try {
      return all.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 交换两个分类的排序位置（用户通过长按拖拽触发）
  /// fromIndex / toIndex 是当前 type 列表内的索引
  Future<void> reorderCategories(int fromIndex, int toIndex, String type) async {
    final list = type == 'income' ? _incomeCategories : _expenseCategories;
    if (fromIndex == toIndex) return;
    if (fromIndex < 0 || fromIndex >= list.length) return;
    if (toIndex < 0 || toIndex >= list.length) return;
    final fromCategory = list[fromIndex];
    final toCategory = list[toIndex];

    // 交换 sort_order 值
    final temp = fromCategory.sortOrder;
    fromCategory.sortOrder = toCategory.sortOrder;
    toCategory.sortOrder = temp;

    // 写回数据库
    try {
      await DatabaseService.instance.updateCategory(fromCategory);
      await DatabaseService.instance.updateCategory(toCategory);
    } catch (e) {
      // 还原 sort_order
      final revert = fromCategory.sortOrder;
      fromCategory.sortOrder = toCategory.sortOrder;
      toCategory.sortOrder = revert;
      debugPrint('reorderCategories failed: $e');
      return;
    }

    // 重新排序并通知 UI
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    notifyListeners();
  }
}
