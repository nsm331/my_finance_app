import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/wallet_model.dart';
import 'database_helper.dart';
import 'hive_db_service.dart';

class DataMigrationService {
  static const String keyIsMigrated = 'is_migrated_to_sqlite';

  static final DataMigrationService instance = DataMigrationService._init();
  factory DataMigrationService() => instance;
  DataMigrationService._init();

  /// Migrates all data from Hive boxes to SQLite relational tables.
  /// Runs only once; guarded by `is_migrated_to_sqlite` boolean in SharedPreferences.
  Future<void> migrateHiveToSqlite({HiveDbService? hiveDbService}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isMigrated = prefs.getBool(keyIsMigrated) ?? false;

      if (isMigrated) {
        debugPrint('[DataMigrationService] Already migrated to SQLite. Skipping.');
        return;
      }

      debugPrint('[DataMigrationService] Starting Hive to SQLite migration...');
      final hiveService = hiveDbService ?? HiveDbService();
      final dbHelper = DatabaseHelper.instance;

      // 1. Ensure default 'كاش' wallet exists in SQLite (ID 1)
      final existingWallets = await dbHelper.getAllWallets();
      int defaultWalletId;
      if (existingWallets.isEmpty) {
        defaultWalletId = await dbHelper.insertWallet(
          const WalletModel(
            name: 'كاش',
            iconCode: 0xf002b, // Icons.payments_rounded
            colorValue: 0xFF10B981, // Emerald Green
          ),
        );
        debugPrint('[DataMigrationService] Default wallet created with ID: $defaultWalletId');
      } else {
        defaultWalletId = existingWallets.first.id ?? 1;
        debugPrint('[DataMigrationService] Using existing default wallet ID: $defaultWalletId');
      }

      // 2. Fetch all legacy data from Hive boxes
      final oldCategories = hiveService.getAllCategories();
      final oldPersons = hiveService.getAllPersons();
      final oldDebts = hiveService.getAllDebts();
      final oldRecurring = hiveService.getAllRecurring();
      final oldTransactions = hiveService.getAllTransactions();

      debugPrint('[DataMigrationService] Found legacy records: '
          '${oldCategories.length} categories, '
          '${oldPersons.length} persons, '
          '${oldDebts.length} debts, '
          '${oldRecurring.length} recurring, '
          '${oldTransactions.length} transactions.');

      // 3. Migrate atomically inside an SQLite transaction
      await dbHelper.runTransaction((txn) async {
        // A. Migrate Categories
        for (final category in oldCategories) {
          await dbHelper.insertCategory(category, txn: txn);
        }

        // B. Migrate Persons
        for (final person in oldPersons) {
          await dbHelper.insertPerson(person, txn: txn);
        }

        // C. Migrate Debts & Payments
        for (final debt in oldDebts) {
          await dbHelper.insertDebt(debt, txn: txn);
        }

        // D. Migrate Recurring Transactions
        for (final recurring in oldRecurring) {
          await dbHelper.insertRecurring(recurring, txn: txn);
        }

        // E. Migrate Transactions
        // Crucial: set wallet_id = defaultWalletId (1) and isTransfer = 0
        for (final tx in oldTransactions) {
          final migratedTx = tx.copyWith(
            walletId: defaultWalletId,
            isTransfer: 0,
          );
          await dbHelper.insertTransaction(migratedTx, txn: txn);
        }
      });

      // 4. Mark migration as successfully completed
      await prefs.setBool(keyIsMigrated, true);
      debugPrint('[DataMigrationService] Hive to SQLite migration completed successfully! '
          '${oldTransactions.length} transactions migrated to wallet ID: $defaultWalletId.');
    } catch (e, stack) {
      debugPrint('[DataMigrationService] ERROR during migration: $e\n$stack');
      // Do NOT set is_migrated_to_sqlite to true so migration can be retried safely
      rethrow;
    }
  }
}
