import 'package:flutter/material.dart';
import '../models/app_currency.dart';
import '../core/utils/currency_formatter.dart';
import '../core/constants/app_colors.dart';

class DebtSummaryCard extends StatelessWidget {
  final AppCurrency currency;
  final double lentRemaining;
  final double borrowedRemaining;
  final VoidCallback? onDetailsTap;

  const DebtSummaryCard({
    super.key,
    required this.currency,
    required this.lentRemaining,
    required this.borrowedRemaining,
    this.onDetailsTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      color: isDark ? AppColors.darkCard : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.handshake_rounded,
                        color: AppColors.primaryTeal,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ملخص الديون (${currency.nameAr})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                if (onDetailsTap != null)
                  TextButton.icon(
                    onPressed: onDetailsTap,
                    icon: const Icon(Icons.arrow_back_ios_rounded, size: 13),
                    label: const Text('التفاصيل', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // 2 Column boxes: ديون لي vs ديون علي
            Row(
              children: [
                // ديون لي (مستحقات)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.debtForMe.withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.debtForMe.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: AppColors.debtForMe,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.call_received_rounded,
                                color: Colors.white,
                                size: 11,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Expanded(
                              child: Text(
                                'ديون لي (مستحقات)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.debtForMe,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            CurrencyFormatter.formatWithCurrency(lentRemaining, currency),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.debtForMe,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'مبالغ أطلبها من الآخرين',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // ديون علي (التزامات)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.debtOnMe.withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.debtOnMe.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: AppColors.debtOnMe,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.call_made_rounded,
                                color: Colors.white,
                                size: 11,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Expanded(
                              child: Text(
                                'ديون علي (التزامات)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.debtOnMe,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            CurrencyFormatter.formatWithCurrency(borrowedRemaining, currency),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.debtOnMe,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'مبالغ يطلبها الآخرون مني',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
    );
  }
}
