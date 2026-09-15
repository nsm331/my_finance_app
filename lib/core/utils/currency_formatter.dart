import 'package:intl/intl.dart';
import '../../models/app_currency.dart';

class CurrencyFormatter {
  static final NumberFormat _formatterWithDecimals = NumberFormat('#,##0.00', 'en_US');
  static final NumberFormat _formatterInteger = NumberFormat('#,##0', 'en_US');

  /// Formats amount into standard clean string, e.g. "1,250" or "1,250.50"
  static String formatAmount(double amount, {bool showDecimals = false}) {
    if (showDecimals || (amount % 1 != 0)) {
      return _formatterWithDecimals.format(amount);
    }
    return _formatterInteger.format(amount);
  }

  /// Formats amount with its currency symbol/code, e.g. "1,500 ر.ي"
  static String format(double amount, AppCurrency currency) => formatWithCurrency(amount, currency);

  static String formatWithCurrency(double amount, AppCurrency currency, {bool showSymbol = true}) {
    final formatted = formatAmount(amount);
    if (showSymbol) {
      return '$formatted ${currency.symbol}';
    }
    return '$formatted ${currency.code}';
  }

  /// Formats amount with sign (+ or -)
  static String formatWithSign(double amount, AppCurrency currency, {required bool isIncome}) {
    final prefix = isIncome ? '+' : '-';
    return '$prefix${formatAmount(amount)} ${currency.symbol}';
  }
}
