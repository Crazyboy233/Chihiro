import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/category.dart';
import '../../providers/category_provider.dart';

class CategoryListScreen extends StatelessWidget {
  const CategoryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('分类管理'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '支出'),
              Tab(text: '收入'),
            ],
          ),
        ),
        body: Consumer<CategoryProvider>(
          builder: (context, provider, child) {
            return TabBarView(
              children: [
                _buildCategoryList(provider.expenseCategories, 'expense'),
                _buildCategoryList(provider.incomeCategories, 'income'),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryList(List<Category> categories, String type) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final category = categories[index];
        return Container(
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
                  color: Color(int.parse('0xFF${category.color.replaceFirst('#', '')}')).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    category.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (category.isDefault == 0) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    // 编辑分类
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    // 删除分类
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
