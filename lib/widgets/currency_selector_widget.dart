import 'package:flutter/material.dart';
import '../models/app_currency.dart';
import '../core/constants/app_colors.dart';

class CurrencySelectorWidget extends StatelessWidget {
  final AppCurrency selectedCurrency;
  final ValueChanged<AppCurrency> onCurrencyChanged;
  final bool isCompact;

  const CurrencySelectorWidget({
    super.key,
    required this.selectedCurrency,
    required this.onCurrencyChanged,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: AppCurrency.values.map((currency) {
          final isSelected = currency == selectedCurrency;
          return Expanded(
            child: GestureDetector(
              onTap: () => onCurrencyChanged(currency),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  vertical: isCompact ? 8 : 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? currency.primaryColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: currency.primaryColor.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      currency.icon,
                      size: isCompact ? 14 : 16,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isCompact ? currency.symbol : currency.nameAr,
                      style: TextStyle(
                        fontSize: isCompact ? 12 : 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
