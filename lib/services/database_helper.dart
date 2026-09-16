import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/app_currency.dart';
import '../models/wallet_model.dart';
import '../models/person_model.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../models/recurring_transaction_model.dart';
import '../models/debt_model.dart';

class DatabaseHelper {
  static const String _databaseName = 'my_finance.db';
  static const int _databaseVersion = 3;

  // Table names
  static const String tableWallets = 'wallets';
  static const String tablePersons = 'persons';
  static const String tableCategories = 'categories';
  static const String tableTransactions = 'transactions';
  static const String tableRecurring = 'recurring_transactions';
  static const String tableDebts = 'debts';
  static const String colUserId = 'user_id';

  // Singleton instance
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  // Active User ID for row-level user isolation
  String? _activeUserId;

  DatabaseHelper._init();

  /// Set the active user ID for filtering and saving records
  void setActiveUserId(String? userId) {
    _activeUserId = userId;
    debugPrint('[DatabaseHelper] Active User ID set to: $_activeUserId');
  }

  /// Get the active user ID
  String? get activeUserId => _activeUserId;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Returns the absolute filesystem path of the SQLite database file
  Future<String> getDatabaseFilePath() async {
    if (kIsWeb) {
      return _databaseName;
    }
    final dbPath = await getDatabasesPath();
    return join(dbPath, _databaseName);
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      final factory = databaseFactoryFfiWeb;
      return await factory.openDatabase(
        _databaseName,
        options: OpenDatabaseOptions(
          version: _databaseVersion,
          onConfigure: _onConfigure,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
          onOpen: _onOpen,
        ),
      );
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // Enable Foreign Keys support in SQLite
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('Upgrading SQLite Database from version $oldVersion to $newVersion...');
    if (oldVersion < 2) {
      await _ensureWalletColumnsExist(db);
    }
    if (oldVersion < 3) {
      await _upgradeToVersion3(db);
    }
  }

  Future<void> _onOpen(Database db) async {
    // Extra safety guarantee that wallet columns and user_id exist across launches
    await _ensureWalletColumnsExist(db);
    await _ensureUserIdColumnsExist(db);
  }

  Future<void> _upgradeToVersion3(Database db) async {
    debugPrint('Upgrading SQLite Database to version 3 (adding user_id columns)...');
    await _ensureUserIdColumnsExist(db);
  }

  Future<void> _ensureUserIdColumnsExist(Database db) async {
    final tables = [
      tableWallets,
      tablePersons,
      tableCategories,
      tableTransactions,
      tableRecurring,
      tableDebts,
    ];

    for (final table in tables) {
      try {
        final info = await db.rawQuery('PRAGMA table_info($table)');
        final columnNames = info.map((row) => row['name']?.toString() ?? '').toSet();
        if (!columnNames.contains('user_id')) {
          await db.execute('ALTER TABLE $table ADD COLUMN user_id TEXT');
          debugPrint('[DatabaseHelper] Successfully added user_id column to table: $table');
        }
      } catch (e) {
        debugPrint('[DatabaseHelper] Note on adding user_id to $table: $e');
      }
    }
  }

  /// Associates any existing local records without user_id with the newly signed in user
  Future<void> linkLocalDataToUser(String userId) async {
    try {
      final db = await database;
      final tables = [
        tableWallets,
        tablePersons,
        tableCategories,
        tableTransactions,
        tableRecurring,
        tableDebts,
      ];
      for (final tbl in tables) {
        await db.execute(
          'UPDATE $tbl SET user_id = ? WHERE user_id IS NULL OR user_id = ""',
          [userId],
        );
      }
      debugPrint('[DatabaseHelper] Successfully linked local data to user: $userId');
    } catch (e) {
      debugPrint('[DatabaseHelper] Error linking local data to user: $e');
    }
  }

  Future<void> _ensureWalletColumnsExist(Database db) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info($tableWallets)');
      final columnNames = info.map((row) => row['name']?.toString() ?? '').toSet();

      if (!columnNames.contains('icon_code')) {
        await db.execute('ALTER TABLE $tableWallets ADD COLUMN icon_code INTEGER NOT NULL DEFAULT 62772');
      }
      if (!columnNames.contains('color_value')) {
        await db.execute('ALTER TABLE $tableWallets ADD COLUMN color_value INTEGER NOT NULL DEFAULT 4279071880');
      }

      // Safeguard: Ensure existing rows don't have NULL for icon_code or color_value
      await db.execute('UPDATE $tableWallets SET icon_code = 62772 WHERE icon_code IS NULL');
      await db.execute('UPDATE $tableWallets SET color_value = 4279071880 WHERE color_value IS NULL');
    } catch (e) {
      debugPrint('Note on ensuring wallet columns: $e');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    debugPrint('Creating SQLite Database tables (version $version)...');

    // 1. Wallets table: id, name, icon_code, color_value, user_id
    await db.execute('''
      CREATE TABLE $tableWallets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon_code INTEGER NOT NULL DEFAULT 62772,
        color_value INTEGER NOT NULL DEFAULT 4279071880,
        user_id TEXT
      )
    ''');

    // 2. Persons table: id, name, phone, notes, created_at, user_id
    await db.execute('''
      CREATE TABLE $tablePersons (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        user_id TEXT
      )
    ''');

    // 3. Categories table: id, name, icon_code, color_value, ..., user_id
    await db.execute('''
      CREATE TABLE $tableCategories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon_code INTEGER NOT NULL,
        color_value INTEGER NOT NULL,
        is_expense INTEGER NOT NULL DEFAULT 1,
        is_default INTEGER NOT NULL DEFAULT 0,
        budgets_json TEXT,
        user_id TEXT
      )
    ''');

    // 4. Transactions table
    await db.execute('''
      CREATE TABLE $tableTransactions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        currency TEXT NOT NULL,
        type TEXT NOT NULL,
        category_id TEXT NOT NULL,
        category_name TEXT NOT NULL,
        category_icon_code INTEGER NOT NULL,
        category_color_value INTEGER NOT NULL,
        date TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        wallet_id INTEGER,
        isTransfer INTEGER NOT NULL DEFAULT 0,
        transfer_id TEXT,
        exchange_rate REAL,
        target_currency TEXT,
        target_amount REAL,
        is_recurring INTEGER NOT NULL DEFAULT 0,
        recurring_id TEXT,
        user_id TEXT,
        FOREIGN KEY (wallet_id) REFERENCES $tableWallets (id) ON DELETE SET NULL
      )
    ''');

    // 5. Recurring Transactions table
    await db.execute('''
      CREATE TABLE $tableRecurring (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        currency TEXT NOT NULL,
        type TEXT NOT NULL,
        category_id TEXT NOT NULL,
        category_name TEXT NOT NULL,
        category_icon_code INTEGER NOT NULL,
        category_color_value INTEGER NOT NULL,
        day_of_month INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        last_processed_date TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        notes TEXT,
        created_at TEXT NOT NULL,
        user_id TEXT
      )
    ''');

    // 6. Debts table
    await db.execute('''
      CREATE TABLE $tableDebts (
        id TEXT PRIMARY KEY,
        person_id TEXT,
        person_name TEXT NOT NULL,
        phone TEXT,
        total_amount REAL NOT NULL,
        currency TEXT NOT NULL,
        type TEXT NOT NULL,
        due_date TEXT,
        created_at TEXT NOT NULL,
        notes TEXT,
        payments_json TEXT NOT NULL DEFAULT '[]',
        user_id TEXT,
        FOREIGN KEY (person_id) REFERENCES $tablePersons (id) ON DELETE SET NULL
      )
    ''');

    debugPrint('All SQLite Database tables created successfully.');
  }

  // ==========================================
  // TRANSACTION EXECUTION (Atomic operations)
  // ==========================================

  Future<T> runTransaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }

  // ==========================================
  // WALLETS CRUD
  // ==========================================

  Future<int> insertWallet(WalletModel wallet, {Transaction? txn}) async {
    try {
      final executor = txn ?? await database;
      final map = Map<String, dynamic>.from(wallet.toMap());
      if (activeUserId != null && activeUserId!.isNotEmpty) {
        map['user_id'] ??= activeUserId;
      }
      return await executor.insert(
        tableWallets,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error inserting wallet: $e');
      rethrow;
    }
  }

  Future<List<WalletModel>> getAllWallets({String? userId}) async {
    try {
      final db = await database;
      final uid = userId ?? activeUserId;
      final whereClause = (uid != null && uid.isNotEmpty) ? 'user_id = ? OR user_id IS NULL' : null;
      final whereArgs = (whereClause != null) ? [uid] : null;
      final maps = await db.query(tableWallets, where: whereClause, whereArgs: whereArgs, orderBy: 'id ASC');
      return maps.map((map) => WalletModel.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting all wallets: $e');
      return [];
    }
  }

  Future<WalletModel?> getWalletById(int id) async {
    try {
      final db = await database;
      final maps = await db.query(
        tableWallets,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (maps.isNotEmpty) {
        return WalletModel.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting wallet by id $id: $e');
      return null;
    }
  }

  Future<int> updateWallet(WalletModel wallet) async {
    try {
      if (wallet.id == null) return 0;
      final db = await database;
      return await db.update(
        tableWallets,
        wallet.toMap(),
        where: 'id = ?',
        whereArgs: [wallet.id],
      );
    } catch (e) {
      debugPrint('Error updating wallet: $e');
      rethrow;
    }
  }

  Future<int> deleteWallet(int id) async {
    try {
      final db = await database;
      return await db.delete(
        tableWallets,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('Error deleting wallet: $e');
      rethrow;
    }
  }

  // ==========================================
  // TRANSACTIONS CRUD
  // ==========================================

  Future<int> insertTransaction(TransactionModel transaction, {Transaction? txn}) async {
    try {
      final executor = txn ?? await database;
      final map = {
        'id': transaction.id,
        'title': transaction.title,
        'amount': transaction.amount,
        'currency': transaction.currency.code,
        'type': transaction.type.name,
        'category_id': transaction.categoryId,
        'category_name': transaction.categoryName,
        'category_icon_code': transaction.categoryIconCode,
        'category_color_value': transaction.categoryColorValue,
        'date': transaction.date.toIso8601String(),
        'notes': transaction.notes,
        'created_at': transaction.createdAt.toIso8601String(),
        'wallet_id': transaction.walletId,
        'isTransfer': transaction.isTransfer,
        'transfer_id': transaction.transferId,
        'exchange_rate': transaction.exchangeRate,
        'target_currency': transaction.targetCurrency?.code,
        'target_amount': transaction.targetAmount,
        'is_recurring': transaction.isRecurring ? 1 : 0,
        'recurring_id': transaction.recurringId,
        if (activeUserId != null && activeUserId!.isNotEmpty) 'user_id': activeUserId,
      };

      return await executor.insert(
        tableTransactions,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error inserting transaction: $e');
      rethrow;
    }
  }

  Future<List<TransactionModel>> getAllTransactions({int? walletId, String? userId}) async {
    try {
      final db = await database;
      final uid = userId ?? activeUserId;
      String? whereClause;
      List<dynamic>? whereArgs;

      if (walletId != null && uid != null && uid.isNotEmpty) {
        whereClause = 'wallet_id = ? AND (user_id = ? OR user_id IS NULL)';
        whereArgs = [walletId, uid];
      } else if (walletId != null) {
        whereClause = 'wallet_id = ?';
        whereArgs = [walletId];
      } else if (uid != null && uid.isNotEmpty) {
        whereClause = 'user_id = ? OR user_id IS NULL';
        whereArgs = [uid];
      }

      final maps = await db.query(
        tableTransactions,
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'date DESC',
      );
      return maps.map((map) => TransactionModel.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting all transactions: $e');
      return [];
    }
  }

  Future<int> updateTransaction(TransactionModel transaction) async {
    try {
      final db = await database;
      final map = {
        'id': transaction.id,
        'title': transaction.title,
        'amount': transaction.amount,
        'currency': transaction.currency.code,
        'type': transaction.type.name,
        'category_id': transaction.categoryId,
        'category_name': transaction.categoryName,
        'category_icon_code': transaction.categoryIconCode,
        'category_color_value': transaction.categoryColorValue,
        'date': transaction.date.toIso8601String(),
        'notes': transaction.notes,
        'created_at': transaction.createdAt.toIso8601String(),
        'wallet_id': transaction.walletId,
        'isTransfer': transaction.isTransfer,
        'transfer_id': transaction.transferId,
        'exchange_rate': transaction.exchangeRate,
        'target_currency': transaction.targetCurrency?.code,
        'target_amount': transaction.targetAmount,
        'is_recurring': transaction.isRecurring ? 1 : 0,
        'recurring_id': transaction.recurringId,
      };

      return await db.update(
        tableTransactions,
        map,
        where: 'id = ?',
        whereArgs: [transaction.id],
      );
    } catch (e) {
      debugPrint('Error updating transaction: $e');
      rethrow;
    }
  }

  Future<int> deleteTransaction(String id) async {
    try {
      final db = await database;
      return await db.delete(
        tableTransactions,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('Error deleting transaction: $e');
      rethrow;
    }
  }

  Future<int> deleteTransactionsByTransferId(String transferId) async {
    try {
      final db = await database;
      return await db.delete(
        tableTransactions,
        where: 'transfer_id = ?',
        whereArgs: [transferId],
      );
    } catch (e) {
      debugPrint('Error deleting transactions by transferId: $e');
      rethrow;
    }
  }

  // ==========================================
  // PERSONS CRUD
  // ==========================================

  Future<int> insertPerson(PersonModel person, {Transaction? txn}) async {
    try {
      final executor = txn ?? await database;
      final map = {
        'id': person.id,
        'name': person.name,
        'phone': person.phone,
        'notes': person.notes,
        'created_at': person.createdAt.toIso8601String(),
        if (activeUserId != null && activeUserId!.isNotEmpty) 'user_id': activeUserId,
      };
      return await executor.insert(
        tablePersons,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error inserting person: $e');
      rethrow;
    }
  }

  Future<List<PersonModel>> getAllPersons({String? userId}) async {
    try {
      final db = await database;
      final uid = userId ?? activeUserId;
      final whereClause = (uid != null && uid.isNotEmpty) ? 'user_id = ? OR user_id IS NULL' : null;
      final whereArgs = (whereClause != null) ? [uid] : null;
      final maps = await db.query(tablePersons, where: whereClause, whereArgs: whereArgs, orderBy: 'name COLLATE NOCASE ASC');
      return maps.map((m) => PersonModel.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Error getting all persons: $e');
      return [];
    }
  }

  Future<int> updatePerson(PersonModel person) async {
    try {
      final db = await database;
      final map = {
        'id': person.id,
        'name': person.name,
        'phone': person.phone,
        'notes': person.notes,
        'created_at': person.createdAt.toIso8601String(),
      };
      return await db.update(
        tablePersons,
        map,
        where: 'id = ?',
        whereArgs: [person.id],
      );
    } catch (e) {
      debugPrint('Error updating person: $e');
      rethrow;
    }
  }

  Future<int> deletePerson(String id) async {
    try {
      final db = await database;
      return await db.delete(
        tablePersons,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('Error deleting person: $e');
      rethrow;
    }
  }

  // ==========================================
  // DEBTS CRUD
  // ==========================================

  Future<int> insertDebt(DebtModel debt, {Transaction? txn}) async {
    try {
      final executor = txn ?? await database;
      final map = {
        'id': debt.id,
        'person_id': debt.personId,
        'person_name': debt.personName,
        'phone': debt.phone,
        'total_amount': debt.totalAmount,
        'currency': debt.currency.code,
        'type': debt.type.name,
        'due_date': debt.dueDate?.toIso8601String(),
        'created_at': debt.createdAt.toIso8601String(),
        'notes': debt.notes,
        'payments_json': jsonEncode(debt.payments.map((p) => p.toMap()).toList()),
        if (activeUserId != null && activeUserId!.isNotEmpty) 'user_id': activeUserId,
      };

      return await executor.insert(
        tableDebts,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error inserting debt: $e');
      rethrow;
    }
  }

  Future<List<DebtModel>> getAllDebts({String? userId}) async {
    try {
      final db = await database;
      final uid = userId ?? activeUserId;
      final whereClause = (uid != null && uid.isNotEmpty) ? 'user_id = ? OR user_id IS NULL' : null;
      final whereArgs = (whereClause != null) ? [uid] : null;
      final maps = await db.query(tableDebts, where: whereClause, whereArgs: whereArgs, orderBy: 'created_at DESC');
      return maps.map((m) => DebtModel.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Error getting all debts: $e');
      return [];
    }
  }

  Future<int> updateDebt(DebtModel debt) async {
    try {
      final db = await database;
      final map = {
        'id': debt.id,
        'person_id': debt.personId,
        'person_name': debt.personName,
        'phone': debt.phone,
        'total_amount': debt.totalAmount,
        'currency': debt.currency.code,
        'type': debt.type.name,
        'due_date': debt.dueDate?.toIso8601String(),
        'created_at': debt.createdAt.toIso8601String(),
        'notes': debt.notes,
        'payments_json': jsonEncode(debt.payments.map((p) => p.toMap()).toList()),
      };

      return await db.update(
        tableDebts,
        map,
        where: 'id = ?',
        whereArgs: [debt.id],
      );
    } catch (e) {
      debugPrint('Error updating debt: $e');
      rethrow;
    }
  }

  Future<int> deleteDebt(String id) async {
    try {
      final db = await database;
      return await db.delete(
        tableDebts,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('Error deleting debt: $e');
      rethrow;
    }
  }

  // ==========================================
  // CATEGORIES CRUD
  // ==========================================

  Future<int> insertCategory(CategoryModel category, {Transaction? txn}) async {
    try {
      final executor = txn ?? await database;
      final map = {
        'id': category.id,
        'name': category.name,
        'icon_code': category.iconCode,
        'color_value': category.colorValue,
        'is_expense': category.isExpense ? 1 : 0,
        'is_default': category.isDefault ? 1 : 0,
        'budgets_json': jsonEncode(category.monthlyBudgets),
        if (activeUserId != null && activeUserId!.isNotEmpty) 'user_id': activeUserId,
      };

      return await executor.insert(
        tableCategories,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error inserting category: $e');
      rethrow;
    }
  }

  Future<List<CategoryModel>> getAllCategories({String? userId}) async {
    try {
      final db = await database;
      final uid = userId ?? activeUserId;
      final whereClause = (uid != null && uid.isNotEmpty) ? 'user_id = ? OR user_id IS NULL' : null;
      final whereArgs = (whereClause != null) ? [uid] : null;
      final maps = await db.query(tableCategories, where: whereClause, whereArgs: whereArgs);
      if (maps.isEmpty) {
        return CategoryModel.defaultCategories;
      }
      return maps.map((m) => CategoryModel.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Error getting all categories: $e');
      return CategoryModel.defaultCategories;
    }
  }

  Future<int> updateCategory(CategoryModel category) async {
    try {
      final db = await database;
      final map = {
        'id': category.id,
        'name': category.name,
        'icon_code': category.iconCode,
        'color_value': category.colorValue,
        'is_expense': category.isExpense ? 1 : 0,
        'is_default': category.isDefault ? 1 : 0,
        'budgets_json': jsonEncode(category.monthlyBudgets),
      };

      return await db.update(
        tableCategories,
        map,
        where: 'id = ?',
        whereArgs: [category.id],
      );
    } catch (e) {
      debugPrint('Error updating category: $e');
      rethrow;
    }
  }

  Future<int> deleteCategory(String id) async {
    try {
      final db = await database;
      return await db.delete(
        tableCategories,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('Error deleting category: $e');
      rethrow;
    }
  }

  // ==========================================
  // RECURRING TRANSACTIONS CRUD
  // ==========================================

  Future<int> insertRecurring(RecurringTransactionModel recurring, {Transaction? txn}) async {
    try {
      final executor = txn ?? await database;
      final map = {
        'id': recurring.id,
        'title': recurring.title,
        'amount': recurring.amount,
        'currency': recurring.currency.code,
        'type': recurring.type.name,
        'category_id': recurring.categoryId,
        'category_name': recurring.categoryName,
        'category_icon_code': recurring.categoryIconCode,
        'category_color_value': recurring.categoryColorValue,
        'day_of_month': recurring.dayOfMonth,
        'start_date': recurring.startDate.toIso8601String(),
        'last_processed_date': recurring.lastProcessedDate?.toIso8601String(),
        'is_active': recurring.isActive ? 1 : 0,
        'notes': recurring.notes,
        'created_at': recurring.createdAt.toIso8601String(),
        if (activeUserId != null && activeUserId!.isNotEmpty) 'user_id': activeUserId,
      };

      return await executor.insert(
        tableRecurring,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error inserting recurring transaction: $e');
      rethrow;
    }
  }

  Future<List<RecurringTransactionModel>> getAllRecurring({String? userId}) async {
    try {
      final db = await database;
      final uid = userId ?? activeUserId;
      final whereClause = (uid != null && uid.isNotEmpty) ? 'user_id = ? OR user_id IS NULL' : null;
      final whereArgs = (whereClause != null) ? [uid] : null;
      final maps = await db.query(tableRecurring, where: whereClause, whereArgs: whereArgs, orderBy: 'day_of_month ASC');
      return maps.map((m) => RecurringTransactionModel.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Error getting all recurring transactions: $e');
      return [];
    }
  }

  Future<int> updateRecurring(RecurringTransactionModel recurring) async {
    try {
      final db = await database;
      final map = {
        'id': recurring.id,
        'title': recurring.title,
        'amount': recurring.amount,
        'currency': recurring.currency.code,
        'type': recurring.type.name,
        'category_id': recurring.categoryId,
        'category_name': recurring.categoryName,
        'category_icon_code': recurring.categoryIconCode,
        'category_color_value': recurring.categoryColorValue,
        'day_of_month': recurring.dayOfMonth,
        'start_date': recurring.startDate.toIso8601String(),
        'last_processed_date': recurring.lastProcessedDate?.toIso8601String(),
        'is_active': recurring.isActive ? 1 : 0,
        'notes': recurring.notes,
        'created_at': recurring.createdAt.toIso8601String(),
      };

      return await db.update(
        tableRecurring,
        map,
        where: 'id = ?',
        whereArgs: [recurring.id],
      );
    } catch (e) {
      debugPrint('Error updating recurring transaction: $e');
      rethrow;
    }
  }

  Future<int> deleteRecurring(String id) async {
    try {
      final db = await database;
      return await db.delete(
        tableRecurring,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('Error deleting recurring transaction: $e');
      rethrow;
    }
  }

  // ==========================================
  // CLOUD SYNC RAW HELPERS
  // ==========================================

  /// Fetches raw table maps for cloud synchronization
  Future<List<Map<String, dynamic>>> getRawTableRows(String table, {required String userId}) async {
    final db = await database;
    return await db.query(
      table,
      where: 'user_id = ? OR user_id IS NULL',
      whereArgs: [userId],
    );
  }

  /// Replaces local table data for a given user during Cloud Restore (Pull)
  Future<void> replaceUserData(String table, List<Map<String, dynamic>> rows, {required String userId}) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(table, where: 'user_id = ?', whereArgs: [userId]);
      for (final row in rows) {
        final map = Map<String, dynamic>.from(row);
        map['user_id'] = userId;
        await txn.insert(table, map, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// Clears data belonging to a specific user
  Future<void> clearUserData(String userId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tableTransactions, where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete(tableDebts, where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete(tablePersons, where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete(tableCategories, where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete(tableRecurring, where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete(tableWallets, where: 'user_id = ?', whereArgs: [userId]);
    });
  }

  // ==========================================
  // BULK & UTILITY OPERATIONS
  // ==========================================

  Future<void> clearAllData() async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete(tableTransactions);
        await txn.delete(tableDebts);
        await txn.delete(tablePersons);
        await txn.delete(tableCategories);
        await txn.delete(tableRecurring);
        await txn.delete(tableWallets);
      });
      debugPrint('All SQLite data cleared successfully.');
    } catch (e) {
      debugPrint('Error clearing SQLite data: $e');
      rethrow;
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
