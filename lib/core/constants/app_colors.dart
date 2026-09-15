import 'package:flutter/material.dart';

class AppColors {
  // Brand & Primary
  static const Color primaryTeal = Color(0xFF0D9488);
  static const Color primaryTealDark = Color(0xFF0F766E);
  static const Color primaryTealLight = Color(0xFF14B8A6);

  // Financial Accents
  static const Color income = Color(0xFF10B981);
  static const Color incomeDark = Color(0xFF059669);
  static const Color expense = Color(0xFFEF4444);
  static const Color expenseDark = Color(0xFFDC2626);

  // Debt Accents
  static const Color debtForMe = Color(0xFF059669); // ديون لي - أخضر
  static const Color debtOnMe = Color(0xFFE11D48);  // ديون علي - وردي أحمر

  // Currencies
  static const Color yerColor = Color(0xFF0D9488);
  static const Color sarColor = Color(0xFFD97706);
  static const Color usdColor = Color(0xFF4F46E5);

  // Light Theme Colors
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightDivider = Color(0xFFF1F5F9);

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF0B1120); // Deep Navy Slate
  static const Color darkSurface = Color(0xFF151E32);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkDivider = Color(0xFF1E293B);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const LinearGradient yerGradient = LinearGradient(
    colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const LinearGradient sarGradient = LinearGradient(
    colors: [Color(0xFFB45309), Color(0xFFF59E0B)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const LinearGradient usdGradient = LinearGradient(
    colors: [Color(0xFF3730A3), Color(0xFF6366F1)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
