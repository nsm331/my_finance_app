import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../models/app_currency.dart';
import '../services/database_helper.dart';

class CategoryProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper;
  List<CategoryModel> _categories = [];
  bool _isLoading = false;

  CategoryProvider({DatabaseHelper? dbHelper, dynamic dbService})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance {
    loadCategories();
  }

  bool get isLoading => _isLoading;
  List<CategoryModel> get categories => List.unmodifiable(_categories);
  List<CategoryModel> get expenseCategories => _categories.where((c) => c.isExpense).toList();
  List<CategoryModel> get incomeCategories => _categories.where((c) => !c.isExpense).toList();

  Future<void> loadCategories() async {
    _isLoading = true;
    notifyListeners();
    try {
      _categories = await _dbHelper.getAllCategories();
    } catch (e) {
      debugPrint('[CategoryProvider] Error loading categories: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  CategoryModel? findById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addCategory(CategoryModel category) async {
    await _dbHelper.insertCategory(category);
    _categories.add(category);
    notifyListeners();
  }

  Future<void> updateCategory(CategoryModel category) async {
    await _dbHelper.updateCategory(category);
    final index = _categories.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      _categories[index] = category;
      notifyListeners();
    }
  }

  Future<void> deleteCategory(String id) async {
    await _dbHelper.deleteCategory(id);
    _categories.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  Future<void> setBudgetLimit({
    required String categoryId,
    required AppCurrency currency,
    required double limit,
  }) async {
    final index = _categories.indexWhere((c) => c.id == categoryId);
    if (index != -1) {
      final old = _categories[index];
      final newBudgets = Map<String, double>.from(old.monthlyBudgets);
      if (limit <= 0) {
        newBudgets.remove(currency.code);
      } else {
        newBudgets[currency.code] = limit;
      }
      final updated = old.copyWith(monthlyBudgets: newBudgets);
      await updateCategory(updated);
    }
  }
}
