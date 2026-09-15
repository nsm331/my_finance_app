import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/utils/icon_helper.dart';
import 'app_currency.dart';

class CategoryModel {
  final String id;
  final String name;
  final int iconCode;
  final int colorValue;
  final bool isExpense;
  final bool isDefault;
  final Map<String, double> monthlyBudgets; // e.g. {'YER': 150000.0, 'SAR': 2000.0, 'USD': 500.0}

  CategoryModel({
    required this.id,
    required this.name,
    required this.iconCode,
    required this.colorValue,
    this.isExpense = true,
    this.isDefault = false,
    Map<String, double>? monthlyBudgets,
  }) : monthlyBudgets = monthlyBudgets ?? {};

  IconData get iconData => AppIcons.getIcon(iconCode);
  Color get color => Color(colorValue);

  double getBudgetForCurrency(AppCurrency currency) {
    return monthlyBudgets[currency.code] ?? 0.0;
  }

  bool hasBudget(AppCurrency currency) {
    return (monthlyBudgets[currency.code] ?? 0.0) > 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon_code': iconCode,
      'color_value': colorValue,
      'is_expense': isExpense ? 1 : 0,
      'is_default': isDefault ? 1 : 0,
      'budgets_json': jsonEncode(monthlyBudgets),
      'monthlyBudgets': monthlyBudgets,
    };
  }

  factory CategoryModel.fromMap(Map<dynamic, dynamic> map) {
    final rawBudgets = map['budgets_json'] ?? map['monthly_budgets'] ?? map['monthlyBudgets'];
    Map<String, double> budgets = {};
    if (rawBudgets is String && rawBudgets.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawBudgets);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            if (value is num) budgets[key.toString()] = value.toDouble();
          });
        }
      } catch (_) {}
    } else if (rawBudgets is Map) {
      rawBudgets.forEach((key, value) {
        if (value is num) {
          budgets[key.toString()] = value.toDouble();
        }
      });
    }

    bool parseBool(dynamic val, bool defaultVal) {
      if (val is bool) return val;
      if (val is int) return val == 1;
      return defaultVal;
    }

    return CategoryModel(
      id: map['id'] as String,
      name: map['name'] as String,
      iconCode: (map['icon_code'] ?? map['iconCode']) as int? ?? Icons.category_rounded.codePoint,
      colorValue: (map['color_value'] ?? map['colorValue']) as int? ?? 0xFF0D9488,
      isExpense: parseBool(map['is_expense'] ?? map['isExpense'], true),
      isDefault: parseBool(map['is_default'] ?? map['isDefault'], false),
      monthlyBudgets: budgets,
    );
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    int? iconCode,
    int? colorValue,
    bool? isExpense,
    bool? isDefault,
    Map<String, double>? monthlyBudgets,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCode: iconCode ?? this.iconCode,
      colorValue: colorValue ?? this.colorValue,
      isExpense: isExpense ?? this.isExpense,
      isDefault: isDefault ?? this.isDefault,
      monthlyBudgets: monthlyBudgets ?? Map.from(this.monthlyBudgets),
    );
  }

  static List<CategoryModel> get defaultCategories => [
    // Expenses
    CategoryModel(
      id: 'food',
      name: 'طعام ومشتريات',
      iconCode: Icons.restaurant_rounded.codePoint,
      colorValue: 0xFFEF4444, // Red
      isExpense: true,
      isDefault: true,
      monthlyBudgets: {'YER': 150000.0, 'SAR': 1500.0, 'USD': 400.0},
    ),
    CategoryModel(
      id: 'bills',
      name: 'فواتير وخدمات',
      iconCode: Icons.receipt_long_rounded.codePoint,
      colorValue: 0xFFF59E0B, // Amber
      isExpense: true,
      isDefault: true,
      monthlyBudgets: {'YER': 50000.0, 'SAR': 600.0, 'USD': 150.0},
    ),
    CategoryModel(
      id: 'transport',
      name: 'مواصلات وبنزين',
      iconCode: Icons.directions_car_rounded.codePoint,
      colorValue: 0xFF3B82F6, // Blue
      isExpense: true,
      isDefault: true,
      monthlyBudgets: {'YER': 40000.0, 'SAR': 500.0, 'USD': 120.0},
    ),
    CategoryModel(
      id: 'shopping',
      name: 'تسوق وملابس',
      iconCode: Icons.shopping_bag_rounded.codePoint,
      colorValue: 0xFF8B5CF6, // Purple
      isExpense: true,
      isDefault: true,
      monthlyBudgets: {'YER': 60000.0, 'SAR': 800.0, 'USD': 200.0},
    ),
    CategoryModel(
      id: 'health',
      name: 'صحة وأدوية',
      iconCode: Icons.medical_services_rounded.codePoint,
      colorValue: 0xFFEC4899, // Pink
      isExpense: true,
      isDefault: true,
      monthlyBudgets: {'YER': 30000.0, 'SAR': 400.0, 'USD': 100.0},
    ),
    CategoryModel(
      id: 'rent',
      name: 'سكن وإيجار',
      iconCode: Icons.home_rounded.codePoint,
      colorValue: 0xFF10B981, // Emerald
      isExpense: true,
      isDefault: true,
      monthlyBudgets: {'YER': 100000.0, 'SAR': 1200.0, 'USD': 300.0},
    ),
    CategoryModel(
      id: 'education',
      name: 'تعليم ودورات',
      iconCode: Icons.school_rounded.codePoint,
      colorValue: 0xFF06B6D4, // Cyan
      isExpense: true,
      isDefault: true,
    ),
    CategoryModel(
      id: 'entertainment',
      name: 'ترفيه وسياحة',
      iconCode: Icons.sports_esports_rounded.codePoint,
      colorValue: 0xFFF97316, // Orange
      isExpense: true,
      isDefault: true,
    ),
    // Income
    CategoryModel(
      id: 'salary',
      name: 'راتب شهري',
      iconCode: Icons.account_balance_rounded.codePoint,
      colorValue: 0xFF10B981, // Green
      isExpense: false,
      isDefault: true,
    ),
    CategoryModel(
      id: 'business',
      name: 'أعمال وتجارة',
      iconCode: Icons.storefront_rounded.codePoint,
      colorValue: 0xFF0D9488, // Teal
      isExpense: false,
      isDefault: true,
    ),
    CategoryModel(
      id: 'freelance',
      name: 'عمل حر (Freelance)',
      iconCode: Icons.laptop_mac_rounded.codePoint,
      colorValue: 0xFF6366F1, // Indigo
      isExpense: false,
      isDefault: true,
    ),
    CategoryModel(
      id: 'investment',
      name: 'استثمار وأرباح',
      iconCode: Icons.trending_up_rounded.codePoint,
      colorValue: 0xFF14B8A6, // Cyan-Teal
      isExpense: false,
      isDefault: true,
    ),
    CategoryModel(
      id: 'other',
      name: 'أخرى ومتنوعة',
      iconCode: Icons.more_horiz_rounded.codePoint,
      colorValue: 0xFF64748B, // Slate
      isExpense: true,
      isDefault: true,
    ),
  ];
}
