import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../providers/category_provider.dart';
import '../core/constants/app_colors.dart';

class CategoryPickerSheet extends StatelessWidget {
  final String? selectedCategoryId;
  final bool isExpense;
  final ValueChanged<CategoryModel> onSelect;
  final VoidCallback? onAddNewCategory;

  const CategoryPickerSheet({
    super.key,
    required this.selectedCategoryId,
    required this.isExpense,
    required this.onSelect,
    this.onAddNewCategory,
  });

  static Future<CategoryModel?> show(
    BuildContext context, {
    String? selectedCategoryId,
    required bool isExpense,
    VoidCallback? onAddNewCategory,
  }) {
    return showModalBottomSheet<CategoryModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CategoryPickerSheet(
        selectedCategoryId: selectedCategoryId,
        isExpense: isExpense,
        onSelect: (cat) => Navigator.pop(ctx, cat),
        onAddNewCategory: onAddNewCategory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final list = isExpense
        ? categoryProvider.expenseCategories
        : categoryProvider.incomeCategories;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isExpense ? 'اختر تصنيف المصروف' : 'اختر تصنيف الدخل',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (onAddNewCategory != null)
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onAddNewCategory!();
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('تصنيف جديد', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Categories Grid
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final cat = list[index];
                final isSelected = cat.id == selectedCategoryId;
                final catColor = cat.color;

                return GestureDetector(
                  onTap: () => onSelect(cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? catColor.withValues(alpha: 0.18)
                          : (isDark ? AppColors.darkSurface : Colors.grey.shade50),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? catColor : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            cat.iconData,
                            color: catColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          cat.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? catColor
                                : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
