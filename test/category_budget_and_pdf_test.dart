import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_finance_app/models/app_currency.dart';
import 'package:my_finance_app/models/category_model.dart';
import 'package:my_finance_app/models/transaction_model.dart';
import 'package:my_finance_app/services/pdf_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Category Drill-Down & Monthly Filtering Tests', () {
    final now = DateTime(2026, 9, 15);
    final prevMonth = DateTime(2026, 8, 20);

    final catFood = CategoryModel(
      id: 'cat_food',
      name: 'طعام ومشروبات',
      iconCode: 1,
      colorValue: 0xFFEF4444,
      isExpense: true,
      monthlyBudgets: {AppCurrency.yer.code: 50000},
    );

    final catSalary = CategoryModel(
      id: 'cat_salary',
      name: 'راتب شهري',
      iconCode: 2,
      colorValue: 0xFF10B981,
      isExpense: false,
    );

    final transactions = [
      TransactionModel(
        id: 't1',
        title: 'غداء عمل',
        amount: 5000,
        currency: AppCurrency.yer,
        type: TransactionType.expense,
        categoryId: catFood.id,
        categoryName: catFood.name,
        categoryIconCode: 1,
        categoryColorValue: 1,
        date: now,
      ),
      TransactionModel(
        id: 't2',
        title: 'عشاء منزلي',
        amount: 8000,
        currency: AppCurrency.yer,
        type: TransactionType.expense,
        categoryId: catFood.id,
        categoryName: catFood.name,
        categoryIconCode: 1,
        categoryColorValue: 1,
        date: now,
      ),
      TransactionModel(
        id: 't3',
        title: 'بقالة الشهر الماضي',
        amount: 12000,
        currency: AppCurrency.yer,
        type: TransactionType.expense,
        categoryId: catFood.id,
        categoryName: catFood.name,
        categoryIconCode: 1,
        categoryColorValue: 1,
        date: prevMonth,
      ),
      TransactionModel(
        id: 't4',
        title: 'راتب سبتمبر',
        amount: 250000,
        currency: AppCurrency.yer,
        type: TransactionType.income,
        categoryId: catSalary.id,
        categoryName: catSalary.name,
        categoryIconCode: 2,
        categoryColorValue: 2,
        date: now,
      ),
    ];

    test('Filter transactions for specific category and month', () {
      final septFoodTxs = transactions.where((t) {
        if (t.categoryId != catFood.id) return false;
        if (t.date.year != now.year || t.date.month != now.month) return false;
        return true;
      }).toList();

      expect(septFoodTxs.length, 2);
      expect(septFoodTxs.map((t) => t.id), containsAll(['t1', 't2']));
      expect(septFoodTxs.map((t) => t.id), isNot(contains('t3')));

      final totalSpent = septFoodTxs.fold(0.0, (sum, t) => sum + t.amount);
      expect(totalSpent, 13000.0);
    });

    test('Monthly transactions excludes past months', () {
      final septAllTxs = transactions.where((t) {
        return t.date.year == now.year && t.date.month == now.month;
      }).toList();

      expect(septAllTxs.length, 3);
      expect(septAllTxs.map((t) => t.id), isNot(contains('t3')));
    });

    test('Budget limit calculation and remaining progress', () {
      final budget = catFood.getBudgetForCurrency(AppCurrency.yer);
      expect(budget, 50000.0);

      const spent = 13000.0;
      final remaining = budget - spent;
      expect(remaining, 37000.0);
      expect(spent / budget, closeTo(0.26, 0.01));
    });
  });

  group('PDF Report Service Generation Tests', () {
    final testMonth = DateTime(2026, 9, 1);

    final catFood = CategoryModel(
      id: 'cat_food',
      name: 'طعام ومشروبات',
      iconCode: 1,
      colorValue: 0xFFEF4444,
      isExpense: true,
      monthlyBudgets: {AppCurrency.yer.code: 50000},
    );

    final txs = [
      TransactionModel(
        id: 'tx_p1',
        title: 'غداء مطعم',
        amount: 6000,
        currency: AppCurrency.yer,
        type: TransactionType.expense,
        categoryId: catFood.id,
        categoryName: catFood.name,
        categoryIconCode: 1,
        categoryColorValue: 1,
        date: DateTime(2026, 9, 5),
        notes: 'مع الزملاء',
      ),
      TransactionModel(
        id: 'tx_p2',
        title: 'بقالة وسوبرماركت',
        amount: 14000,
        currency: AppCurrency.yer,
        type: TransactionType.expense,
        categoryId: catFood.id,
        categoryName: catFood.name,
        categoryIconCode: 1,
        categoryColorValue: 1,
        date: DateTime(2026, 9, 12),
        notes: 'مشتريات أسبوعية',
      ),
    ];

    test('generateCategoryReportBytes generates non-empty valid PDF bytes', () async {
      final Uint8List pdfBytes = await PdfReportService.generateCategoryReportBytes(
        category: catFood,
        month: testMonth,
        categoryTransactions: txs,
        currency: AppCurrency.yer,
      );

      expect(pdfBytes, isNotEmpty);
      // Valid PDF magic header: %PDF-
      final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(header, '%PDF-');
    });

    test('generateMonthlyReportBytes generates non-empty valid PDF bytes with categories summary', () async {
      final Uint8List pdfBytes = await PdfReportService.generateMonthlyReportBytes(
        month: testMonth,
        allTransactions: txs,
        categories: [catFood],
        currency: AppCurrency.yer,
      );

      expect(pdfBytes, isNotEmpty);
      final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(header, '%PDF-');
    });
  });
}
