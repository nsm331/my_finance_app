import 'package:flutter_test/flutter_test.dart';
import 'package:my_finance_app/models/app_currency.dart';
import 'package:my_finance_app/models/wallet_model.dart';
import 'package:my_finance_app/models/transaction_model.dart';
import 'package:my_finance_app/models/debt_model.dart';
import 'package:my_finance_app/models/debt_payment_model.dart';
import 'package:my_finance_app/models/person_model.dart';
import 'package:my_finance_app/models/category_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4 & 5 Wallets, Double-Entry & Providers Logic Tests', () {
    test('Multi-currency wallet balances calculation', () {
      final w1 = WalletModel(id: 1, name: 'كاش');
      final w2 = WalletModel(id: 2, name: 'بنك الكريمي');

      final transactions = [
        // Wallet 1 (كاش)
        TransactionModel(
          id: 'tx1',
          title: 'راتب',
          amount: 100000,
          currency: AppCurrency.yer,
          type: TransactionType.income,
          categoryId: 'salary',
          categoryName: 'راتب',
          categoryIconCode: 1,
          categoryColorValue: 1,
          date: DateTime.now(),
          walletId: w1.id,
        ),
        TransactionModel(
          id: 'tx2',
          title: 'بقالة',
          amount: 25000,
          currency: AppCurrency.yer,
          type: TransactionType.expense,
          categoryId: 'groceries',
          categoryName: 'بقالة',
          categoryIconCode: 1,
          categoryColorValue: 1,
          date: DateTime.now(),
          walletId: w1.id,
        ),
        TransactionModel(
          id: 'tx3',
          title: 'تحويل دولار',
          amount: 50,
          currency: AppCurrency.usd,
          type: TransactionType.income,
          categoryId: 'income',
          categoryName: 'دخل',
          categoryIconCode: 1,
          categoryColorValue: 1,
          date: DateTime.now(),
          walletId: w1.id,
        ),

        // Wallet 2 (بنك الكريمي)
        TransactionModel(
          id: 'tx4',
          title: 'إيداع تجاري',
          amount: 500,
          currency: AppCurrency.sar,
          type: TransactionType.income,
          categoryId: 'business',
          categoryName: 'تجارة',
          categoryIconCode: 1,
          categoryColorValue: 1,
          date: DateTime.now(),
          walletId: w2.id,
        ),
      ];

      // Helper calculation logic
      double getWalletBalance(int walletId, AppCurrency currency) {
        final income = transactions
            .where((t) => t.walletId == walletId && t.currency == currency && t.type == TransactionType.income)
            .fold(0.0, (sum, t) => sum + t.amount);
        final expense = transactions
            .where((t) => t.walletId == walletId && t.currency == currency && t.type == TransactionType.expense)
            .fold(0.0, (sum, t) => sum + t.amount);
        return income - expense;
      }

      // Wallet 1 checks
      expect(getWalletBalance(1, AppCurrency.yer), 75000); // 100,000 - 25,000
      expect(getWalletBalance(1, AppCurrency.usd), 50);
      expect(getWalletBalance(1, AppCurrency.sar), 0);

      // Wallet 2 checks
      expect(getWalletBalance(2, AppCurrency.sar), 500);
      expect(getWalletBalance(2, AppCurrency.yer), 0);
    });

    test('Double-entry wallet transfer maintains grand total assets (net 0 impact)', () {
      final List<TransactionModel> transactions = [
        TransactionModel(
          id: 'init_tx',
          title: 'رصيد أولي',
          amount: 50000,
          currency: AppCurrency.yer,
          type: TransactionType.income,
          categoryId: 'init',
          categoryName: 'رصيد أولي',
          categoryIconCode: 1,
          categoryColorValue: 1,
          date: DateTime.now(),
          walletId: 1, // Wallet 1
        ),
      ];

      double getTotalIncome(AppCurrency cur) {
        return transactions
            .where((t) => t.currency == cur && t.type == TransactionType.income && !t.isWalletTransfer)
            .fold(0.0, (sum, t) => sum + t.amount);
      }

      double getTotalExpense(AppCurrency cur) {
        return transactions
            .where((t) => t.currency == cur && t.type == TransactionType.expense && !t.isWalletTransfer)
            .fold(0.0, (sum, t) => sum + t.amount);
      }

      double grandTotal(AppCurrency cur) {
        return getTotalIncome(cur) - getTotalExpense(cur);
      }

      double getWalletBalance(int walletId, AppCurrency cur) {
        final income = transactions
            .where((t) => t.walletId == walletId && t.currency == cur && t.type == TransactionType.income)
            .fold(0.0, (sum, t) => sum + t.amount);
        final expense = transactions
            .where((t) => t.walletId == walletId && t.currency == cur && t.type == TransactionType.expense)
            .fold(0.0, (sum, t) => sum + t.amount);
        return income - expense;
      }

      expect(getTotalIncome(AppCurrency.yer), 50000);
      expect(getTotalExpense(AppCurrency.yer), 0);
      expect(grandTotal(AppCurrency.yer), 50000);
      expect(getWalletBalance(1, AppCurrency.yer), 50000);
      expect(getWalletBalance(2, AppCurrency.yer), 0);

      // Transfer 20,000 YER from Wallet 1 to Wallet 2
      final transferId = 'wallet_transfer_123';
      final outTx = TransactionModel(
        id: 'out_1',
        title: 'تحويل إلى المحفظة 2',
        amount: 20000,
        currency: AppCurrency.yer,
        type: TransactionType.expense,
        categoryId: 'wallet_transfer',
        categoryName: 'تحويل بين المحافظ',
        categoryIconCode: 1,
        categoryColorValue: 1,
        date: DateTime.now(),
        walletId: 1,
        isTransfer: 1,
        transferId: transferId,
      );

      final inTx = TransactionModel(
        id: 'in_1',
        title: 'استلام تحويل من المحفظة 1',
        amount: 20000,
        currency: AppCurrency.yer,
        type: TransactionType.income,
        categoryId: 'wallet_transfer',
        categoryName: 'تحويل بين المحافظ',
        categoryIconCode: 1,
        categoryColorValue: 1,
        date: DateTime.now(),
        walletId: 2,
        isTransfer: 1,
        transferId: transferId,
      );

      transactions.add(outTx);
      transactions.add(inTx);

      expect(outTx.isWalletTransfer, true);
      expect(inTx.isWalletTransfer, true);

      // CRITICAL: Transfers do NOT inflate total income or total expense
      expect(getTotalIncome(AppCurrency.yer), 50000); // Remained 50,000, NOT inflated to 70,000!
      expect(getTotalExpense(AppCurrency.yer), 0);     // Remained 0, NOT inflated to 20,000!

      // Individual wallet balances reflect transfer correctly
      expect(getWalletBalance(1, AppCurrency.yer), 30000); // 50,000 - 20,000
      expect(getWalletBalance(2, AppCurrency.yer), 20000); // 0 + 20,000

      // Grand total balance across ALL wallets remains identical (50,000 YER)
      expect(grandTotal(AppCurrency.yer), 50000);

      // Filter verification:
      // When filtering expenses (excluding transfers), list is empty
      final expensesOnly = transactions
          .where((t) => t.type == TransactionType.expense && !t.isWalletTransfer)
          .toList();
      expect(expensesOnly, isEmpty);

      // When filtering transfers only, both transactions are returned
      final transfersOnly = transactions
          .where((t) => t.isWalletTransfer)
          .toList();
      expect(transfersOnly.length, 2);
    });

    test('DebtModel and payments calculation', () {
      final debt = DebtModel(
        id: 'd1',
        personName: 'محمد أحمد',
        totalAmount: 10000,
        currency: AppCurrency.yer,
        type: DebtType.forMe,
        payments: [
          DebtPaymentModel(
            id: 'p1',
            debtId: 'd1',
            amount: 4000,
            date: DateTime.now(),
          ),
        ],
      );

      expect(debt.paidAmount, 4000);
      expect(debt.remainingAmount, 6000);
      expect(debt.isSettled, false);
      expect(debt.isFullyPaid, false);

      final fullyPaidDebt = debt.copyWith(
        payments: [
          ...debt.payments,
          DebtPaymentModel(
            id: 'p2',
            debtId: 'd1',
            amount: 6000,
            date: DateTime.now(),
          ),
        ],
      );

      expect(fullyPaidDebt.paidAmount, 10000);
      expect(fullyPaidDebt.remainingAmount, 0);
      expect(fullyPaidDebt.isSettled, true);
      expect(fullyPaidDebt.isFullyPaid, true);

      // Payment Edit: changing p1 from 4000 to 7000
      final updatedPayments = fullyPaidDebt.payments.map((p) {
        if (p.id == 'p1') {
          return DebtPaymentModel(
            id: p.id,
            debtId: p.debtId,
            amount: 7000,
            date: p.date,
          );
        }
        return p;
      }).toList();
      final editedDebt = fullyPaidDebt.copyWith(payments: updatedPayments);
      expect(editedDebt.paidAmount, 13000); // 7000 + 6000
      expect(editedDebt.remainingAmount, 0);

      // Payment Delete: removing p2 (6000)
      final remainingPayments = editedDebt.payments.where((p) => p.id != 'p2').toList();
      final afterDeleteDebt = editedDebt.copyWith(payments: remainingPayments);
      expect(afterDeleteDebt.payments.length, 1);
      expect(afterDeleteDebt.paidAmount, 7000);
      expect(afterDeleteDebt.remainingAmount, 3000);
      expect(afterDeleteDebt.isSettled, false);
    });

    test('Cascading deletion of Person removes associated debts from list', () {
      final p1 = PersonModel(id: 'person_1', name: 'خالد عمر');
      final p2 = PersonModel(id: 'person_2', name: 'أحمد علي');

      List<DebtModel> debts = [
        DebtModel(id: 'debt_1', personId: 'person_1', personName: 'خالد عمر', totalAmount: 5000, currency: AppCurrency.yer, type: DebtType.forMe),
        DebtModel(id: 'debt_2', personId: 'person_1', personName: 'خالد عمر', totalAmount: 3000, currency: AppCurrency.yer, type: DebtType.onMe),
        DebtModel(id: 'debt_3', personId: 'person_2', personName: 'أحمد علي', totalAmount: 8000, currency: AppCurrency.yer, type: DebtType.forMe),
      ];

      expect(debts.length, 3);

      // Cascade delete person_1
      debts.removeWhere((d) => d.personId == p1.id);
      expect(debts.length, 1);
      expect(debts.first.personId, p2.id);
      expect(debts.first.personName, 'أحمد علي');
    });

    test('CategoryModel budgets and serialization', () {
      final cat = CategoryModel(
        id: 'cat_groceries',
        name: 'بقالة ومواد غذائية',
        iconCode: 0xe040,
        colorValue: 0xFF10B981,
        isExpense: true,
        monthlyBudgets: {
          'YER': 150000,
          'SAR': 1000,
        },
      );

      expect(cat.getBudgetForCurrency(AppCurrency.yer), 150000);
      expect(cat.getBudgetForCurrency(AppCurrency.sar), 1000);
      expect(cat.getBudgetForCurrency(AppCurrency.usd), 0.0);

      final map = cat.toMap();
      expect(map['is_expense'], 1);

      final restored = CategoryModel.fromMap(map);
      expect(restored.name, 'بقالة ومواد غذائية');
      expect(restored.getBudgetForCurrency(AppCurrency.yer), 150000);
    });
  });
}
