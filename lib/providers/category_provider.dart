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
}
