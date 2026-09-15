import 'package:flutter_test/flutter_test.dart';
import 'package:my_finance_app/models/app_currency.dart';
import 'package:my_finance_app/models/transaction_model.dart';
import 'package:my_finance_app/models/debt_model.dart';
import 'package:my_finance_app/core/utils/currency_formatter.dart';

void main() {
  test('AppCurrency tests', () {
    expect(AppCurrency.yer.code, 'YER');
    expect(AppCurrency.sar.code, 'SAR');
    expect(AppCurrency.usd.code, 'USD');
    expect(AppCurrency.yer.symbol, 'ر.ي');
    expect(AppCurrency.sar.symbol, 'ر.س');
    expect(AppCurrency.usd.symbol, '\$');
  });

  test('CurrencyFormatter tests', () {
    expect(CurrencyFormatter.formatAmount(1500), '1,500');
    expect(CurrencyFormatter.formatWithCurrency(1500, AppCurrency.yer), '1,500 ر.ي');
    expect(CurrencyFormatter.formatWithSign(250, AppCurrency.usd, isIncome: true), '+250 \$');
    expect(CurrencyFormatter.formatWithSign(100, AppCurrency.sar, isIncome: false), '-100 ر.س');
  });

  test('TransactionModel serialization', () {
    final tx = TransactionModel(
      id: 'tx1',
      title: 'راتب',
      amount: 500000,
      currency: AppCurrency.yer,
      type: TransactionType.income,
      categoryId: 'salary',
      categoryName: 'راتب شهري',
      categoryIconCode: 0xe040,
      categoryColorValue: 0xFF10B981,
      date: DateTime(2026, 8, 14),
    );

    final map = tx.toMap();
    final reconstructed = TransactionModel.fromMap(map);

    expect(reconstructed.id, 'tx1');
    expect(reconstructed.title, 'راتب');
    expect(reconstructed.amount, 500000);
    expect(reconstructed.currency, AppCurrency.yer);
    expect(reconstructed.type, TransactionType.income);
  });

  test('DebtModel calculations', () {
    final debt = DebtModel(
      id: 'd1',
      personName: 'أحمد',
      totalAmount: 1000,
      currency: AppCurrency.sar,
      type: DebtType.forMe,
    );

    expect(debt.paidAmount, 0.0);
    expect(debt.remainingAmount, 1000.0);
    expect(debt.isSettled, false);
    expect(debt.progress, 0.0);
  });
}
