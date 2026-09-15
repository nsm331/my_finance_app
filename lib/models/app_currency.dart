import 'package:flutter/material.dart';

enum AppCurrency {
  yer, // ريال يمني
  sar, // ريال سعودي
  usd; // دولار أمريكي

  static AppCurrency fromCode(String? val) => fromString(val);

  static AppCurrency fromString(String? val) {
    if (val == null) return AppCurrency.yer;
    switch (val.toUpperCase()) {
      case 'SAR':
        return AppCurrency.sar;
      case 'USD':
        return AppCurrency.usd;
      case 'YER':
      default:
        return AppCurrency.yer;
    }
  }
}

extension AppCurrencyExtension on AppCurrency {
  String get code {
    switch (this) {
      case AppCurrency.yer:
        return 'YER';
      case AppCurrency.sar:
        return 'SAR';
      case AppCurrency.usd:
        return 'USD';
    }
  }

  String get nameAr {
    switch (this) {
      case AppCurrency.yer:
        return 'ريال يمني';
      case AppCurrency.sar:
        return 'ريال سعودي';
      case AppCurrency.usd:
        return 'دولار أمريكي';
    }
  }

  String get symbol {
    switch (this) {
      case AppCurrency.yer:
        return 'ر.ي';
      case AppCurrency.sar:
        return 'ر.س';
      case AppCurrency.usd:
        return '\$';
    }
  }

  IconData get icon {
    switch (this) {
      case AppCurrency.yer:
        return Icons.account_balance_wallet_rounded;
      case AppCurrency.sar:
        return Icons.monetization_on_rounded;
      case AppCurrency.usd:
        return Icons.attach_money_rounded;
    }
  }

  Color get primaryColor {
    switch (this) {
      case AppCurrency.yer:
        return const Color(0xFF0D9488); // Teal
      case AppCurrency.sar:
        return const Color(0xFFD97706); // Amber
      case AppCurrency.usd:
        return const Color(0xFF4F46E5); // Indigo
    }
  }

  Color get gradientStart {
    switch (this) {
      case AppCurrency.yer:
        return const Color(0xFF0F766E);
      case AppCurrency.sar:
        return const Color(0xFFB45309);
      case AppCurrency.usd:
        return const Color(0xFF4338CA);
    }
  }

  Color get gradientEnd {
    switch (this) {
      case AppCurrency.yer:
        return const Color(0xFF14B8A6);
      case AppCurrency.sar:
        return const Color(0xFFF59E0B);
      case AppCurrency.usd:
        return const Color(0xFF6366F1);
    }
  }

  static AppCurrency fromCode(String? val) => AppCurrency.fromCode(val);
  static AppCurrency fromString(String? val) => AppCurrency.fromString(val);
}
