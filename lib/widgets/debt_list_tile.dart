import 'package:flutter/material.dart';
import '../models/debt_model.dart';
import '../core/utils/currency_formatter.dart';
import '../core/utils/date_formatter.dart';
import '../core/constants/app_colors.dart';

class DebtListTile extends StatelessWidget {
  final DebtModel debt;
  final VoidCallback? onTap;
  final VoidCallback? onPaymentTap;

  const DebtListTile({
    super.key,
    required this.debt,
    this.onTap,
    this.onPaymentTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isForMe = debt.type == DebtType.forMe;
    final themeColor = isForMe ? AppColors.debtForMe : AppColors.debtOnMe;
    final isSettled = debt.isSettled;

    return Card(
      color: isDark ? AppColors.darkCard : AppColors.lightSurface,
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isSettled
              ? Colors.grey.shade400.withValues(alpha: 0.3)
              : themeColor.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Person Name + Debt Type Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: themeColor.withValues(alpha: 0.12),
                        child: Text(
                          debt.personName.isNotEmpty ? debt.personName[0] : '؟',
                          style: TextStyle(
                            color: themeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            debt.personName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (debt.phone != null && debt.phone!.isNotEmpty)
                            Text(
                              debt.phone!,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),

                  // Debt Type Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSettled
                          ? Colors.grey.shade200
                          : themeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isSettled ? 'مسدد بالكامل' : debt.type.nameAr,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSettled ? Colors.grey.shade700 : themeColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Middle: Amount Breakdown
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المبلغ المتبقي',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.formatWithCurrency(debt.remainingAmount, debt.currency),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: isSettled
                              ? Colors.grey
                              : (isForMe ? AppColors.debtForMe : AppColors.debtOnMe),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'إجمالي الدين',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.formatWithCurrency(debt.totalAmount, debt.currency),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: debt.progress,
                  minHeight: 6,
                  backgroundColor: isDark ? AppColors.darkSurface : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isSettled ? AppColors.income : themeColor,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Bottom Row: Due date + Pay button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (debt.dueDate != null)
                    Row(
                      children: [
                        Icon(
                          Icons.event_rounded,
                          size: 14,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'استحقاق: ${DateFormatter.formatDate(debt.dueDate!)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    )
                  else
                    const SizedBox.shrink(),

                  if (!isSettled && onPaymentTap != null)
                    InkWell(
                      onTap: onPaymentTap,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: themeColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.payment_rounded, size: 14, color: themeColor),
                            const SizedBox(width: 4),
                            Text(
                              'تسديد دفعة',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: themeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
