import 'package:flutter_test/flutter_test.dart';
import 'package:my_finance_app/models/app_currency.dart';
import 'package:my_finance_app/models/wallet_model.dart';
import 'package:my_finance_app/models/person_model.dart';
import 'package:my_finance_app/models/transaction_model.dart';
import 'package:my_finance_app/models/debt_model.dart';
import 'package:my_finance_app/models/debt_payment_model.dart';

void main() {
  group('Phase 1 & 2 Models & SQLite Compatibility Tests', () {
    test('WalletModel serialization and properties', () {
      final wallet = WalletModel(
        id: 1,
        name: 'كاش',
        iconCode: 0xf002b,
        colorValue: 0xFF10B981,
      );
      final map = wallet.toMap();

      expect(map['id'], 1);
      expect(map['name'], 'كاش');
      expect(map['icon_code'], 0xf002b);
      expect(map['color_value'], 0xFF10B981);

      final fromMap = WalletModel.fromMap(map);
      expect(fromMap.id, 1);
      expect(fromMap.name, 'كاش');
      expect(fromMap.iconCode, 0xf002b);
      expect(fromMap.colorValue, 0xFF10B981);
      expect(fromMap.color.toARGB32(), 0xFF10B981);

      // Default values when omitted from legacy map
      final legacyMap = {'id': 2, 'name': 'بنك'};
      final fromLegacy = WalletModel.fromMap(legacyMap);
      expect(fromLegacy.id, 2);
      expect(fromLegacy.name, 'بنك');
      expect(fromLegacy.iconCode, 0xf534);
      expect(fromLegacy.colorValue, 0xFF0D9488);

      // Safe handling when icon_code or color_value are explicitly null
      final nullMap = {'id': 3, 'name': 'محفظة', 'icon_code': null, 'color_value': null};
      final fromNull = WalletModel.fromMap(nullMap);
      expect(fromNull.id, 3);
      expect(fromNull.iconCode, 0xf534);
      expect(fromNull.colorValue, 0xFF0D9488);
      expect(fromNull.color.toARGB32(), 0xFF0D9488);
    });

    test('TransactionModel with walletId and isTransfer', () {
      final tx = TransactionModel(
        id: 'tx_sql_1',
        title: 'شراء أغراض',
        amount: 4500.0,
        currency: AppCurrency.yer,
        type: TransactionType.expense,
        categoryId: 'groceries',
        categoryName: 'بقالة',
        categoryIconCode: 1234,
        categoryColorValue: 0xFF123456,
        date: DateTime(2026, 9, 5, 12, 0),
        walletId: 1,
        isTransfer: 0,
      );

      final map = tx.toMap();
      expect(map['wallet_id'], 1);
      expect(map['isTransfer'], 0);

      final reconstructed = TransactionModel.fromMap(map);
      expect(reconstructed.id, 'tx_sql_1');
      expect(reconstructed.walletId, 1);
      expect(reconstructed.isTransfer, 0);
      expect(reconstructed.isTransferBool, false);
    });

    test('TransactionModel parses legacy Hive format with bool isTransfer', () {
      final legacyMap = {
        'id': 'legacy_1',
        'title': 'تحويل قديم',
        'amount': 100.0,
        'currency': 'USD',
        'type': 'expense',
        'categoryId': 'transfer',
        'categoryName': 'تحويل',
        'categoryIconCode': 0,
        'categoryColorValue': 0,
        'date': DateTime.now().toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
        'isTransfer': true,
      };

      final tx = TransactionModel.fromMap(legacyMap);
      expect(tx.isTransfer, 1);
      expect(tx.isTransferBool, true);
    });

    test('PersonModel serialization with created_at and createdAt', () {
      final person = PersonModel(
        id: 'p1',
        name: 'محمد علي',
        phone: '777123456',
        notes: 'صديق',
      );

      final map = person.toMap();
      expect(map['id'], 'p1');
      expect(map['name'], 'محمد علي');
      expect(map['phone'], '777123456');
      expect(map['created_at'], isNotNull);

      // Reconstruct from SQL map
      final fromSql = PersonModel.fromMap(map);
      expect(fromSql.name, 'محمد علي');

      // Reconstruct from legacy Hive map
      final legacyMap = {
        'id': 'p2',
        'name': 'خالد',
        'createdAt': DateTime.now().toIso8601String(),
      };
      final fromLegacy = PersonModel.fromMap(legacyMap);
      expect(fromLegacy.name, 'خالد');
    });

    test('DebtModel serializes and deserializes payments as JSON', () {
      final debt = DebtModel(
        id: 'd1',
        personId: 'p1',
        personName: 'محمد علي',
        totalAmount: 50000.0,
        currency: AppCurrency.yer,
        type: DebtType.forMe,
        payments: [
          DebtPaymentModel(
            id: 'pay1',
            debtId: 'd1',
            amount: 15000.0,
            date: DateTime.now(),
            impactsBalance: true,
          ),
        ],
      );

      final map = debt.toMap();
      expect(map['payments'], isA<String>()); // JSON string for SQLite

      final reconstructed = DebtModel.fromMap(map);
      expect(reconstructed.id, 'd1');
      expect(reconstructed.payments.length, 1);
      expect(reconstructed.payments.first.amount, 15000.0);
      expect(reconstructed.payments.first.impactsBalance, true);
      expect(reconstructed.paidAmount, 15000.0);
      expect(reconstructed.remainingAmount, 35000.0);
    });
  });
}
