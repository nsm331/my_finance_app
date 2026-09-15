import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../models/app_currency.dart';
import '../core/utils/currency_formatter.dart';
import '../core/constants/app_colors.dart';

class BudgetProgressCard extends StatelessWidget {
  final CategoryModel category;
  final AppCurrency currency;
  final double spentAmount;
  final VoidCallback? onSetBudget;

  const BudgetProgressCard({
    super.key,
    required this.category,
    required this.currency,
    required this.spentAmount,
    this.onSetBudget,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final budget = category.getBudgetForCurrency(currency);
    final hasBudget = budget > 0;
    final percentage = hasBudget ? (spentAmount / budget) : 0.0;
    final categoryColor = category.color;

    Color progressColor;
    if (percentage >= 1.0) {
      progressColor = AppColors.expense;
    } else if (percentage >= 0.8) {
      progressColor = const Color(0xFFF59E0B); // Amber warning
    } else {
      progressColor = AppColors.income;
    }

    return Card(
      color: isDark ? AppColors.darkCard : AppColors.lightSurface,
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: percentage >= 1.0
              ? AppColors.expense.withValues(alpha: 0.4)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: percentage >= 1.0 ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Top: Category info + Edit budget button
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    category.iconData,
                    color: categoryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasBudget
                            ? 'تم استهلاك ${(percentage * 100).toStringAsFixed(0)}% من الميزانية'
                            : 'لم يتم تحديد سقف شهري',
                        style: TextStyle(
                          fontSize: 11,
                          color: hasBudget
                              ? (percentage >= 1.0 ? AppColors.expense : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary))
                              : Colors.grey,
                          fontWeight: percentage >= 1.0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onSetBudget != null)
                  IconButton(
                    icon: Icon(
                      hasBudget ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
                      size: 22,
                      color: AppColors.primaryTeal,
                    ),
                    tooltip: 'تحديد الميزانية',
                    onPressed: onSetBudget,
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Progress Bar if budget is set
            if (hasBudget) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: percentage.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: isDark ? AppColors.darkSurface : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'المنفق: ${CurrencyFormatter.formatWithCurrency(spentAmount, currency)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: progressColor,
                    ),
                  ),
                  Text(
                    'السقف: ${CurrencyFormatter.formatWithCurrency(budget, currency)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'المنفق هذا الشهر: ${CurrencyFormatter.formatWithCurrency(spentAmount, currency)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: onSetBudget,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('تعيين سقف +', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
