import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../models/recurring_transaction_model.dart';
import '../models/wallet_model.dart';
import '../models/app_currency.dart';
import '../services/database_helper.dart';

class FinanceProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper;
  List<TransactionModel> _transactions = [];
  List<RecurringTransactionModel> _recurringTransactions = [];
  List<WalletModel> _wallets = [];
  bool _isLoading = false;

  FinanceProvider({DatabaseHelper? dbHelper, dynamic dbService})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance {
    loadAllData();
  }

  bool get isLoading => _isLoading;
  List<TransactionModel> get transactions => List.unmodifiable(_transactions);
  List<RecurringTransactionModel> get recurringTransactions => List.unmodifiable(_recurringTransactions);
  List<WalletModel> get wallets => List.unmodifiable(_wallets);

  /// Loads all data from SQLite database
  Future<void> loadAllData() async {
    _isLoading = true;
    notifyListeners();
    try {
      await Future.wait([
        loadWallets(notify: false),
        loadTransactions(notify: false),
        loadRecurringTransactions(notify: false),
      ]);
    } catch (e) {
      debugPrint('[FinanceProvider] Error loading data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
      await processDueRecurringTransactions();
    }
  }

  Future<void> loadWallets({bool notify = true}) async {
    _wallets = await _dbHelper.getAllWallets();
    if (_wallets.isEmpty) {
      // Ensure default cash wallet exists
      final defaultId = await _dbHelper.insertWallet(const WalletModel(name: 'كاش'));
      _wallets = [WalletModel(id: defaultId, name: 'كاش')];
    }
    if (notify) notifyListeners();
  }

  Future<void> loadTransactions({bool notify = true}) async {
    _transactions = await _dbHelper.getAllTransactions();
    if (notify) notifyListeners();
  }

  Future<void> loadRecurringTransactions({bool notify = true}) async {
    _recurringTransactions = await _dbHelper.getAllRecurring();
    if (notify) notifyListeners();
  }

  // ================= Transactions CRUD =================

  Future<void> addTransaction(TransactionModel transaction) async {
    // If walletId is null, assign to the first/default wallet
    TransactionModel txToSave = transaction;
    if (txToSave.walletId == null && _wallets.isNotEmpty) {
      txToSave = txToSave.copyWith(walletId: _wallets.first.id ?? 1);
    }

    await _dbHelper.insertTransaction(txToSave);
    _transactions.insert(0, txToSave);
    _transactions.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    await _dbHelper.updateTransaction(transaction);
    final index = _transactions.indexWhere((t) => t.id == transaction.id);
    if (index != -1) {
      _transactions[index] = transaction;
      _transactions.sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();
    }
  }

  Future<void> deleteTransaction(String id) async {
    // If it's a transfer, check if user also wants to delete paired transaction
    final target = _transactions.firstWhere(
      (t) => t.id == id,
      orElse: () => TransactionModel(
        id: '',
        title: '',
        amount: 0,
        currency: AppCurrency.yer,
        type: TransactionType.expense,
        categoryId: '',
        categoryName: '',
        categoryIconCode: 0,
        categoryColorValue: 0,
        date: DateTime.now(),
      ),
    );

    if (target.isTransferBool && target.transferId != null) {
      // Delete both parts of transfer
      await deleteTransferPair(target.transferId!);
      return;
    }

    await _dbHelper.deleteTransaction(id);
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  // ================= Currency Transfer & Exchange =================

  /// Executes an atomic currency exchange between two currencies
  Future<void> executeCurrencyTransfer({
    required AppCurrency fromCurrency,
    required AppCurrency toCurrency,
    required double fromAmount,
    required double exchangeRate,
    double? customToAmount,
    required DateTime date,
    String? notes,
    int? walletId,
  }) async {
    final toAmount = customToAmount ?? (fromAmount * exchangeRate);
    final transferId = 'transfer_${const Uuid().v4()}';
    final outId = const Uuid().v4();
    final inId = const Uuid().v4();
    final targetWalletId = walletId ?? (_wallets.isNotEmpty ? _wallets.first.id : 1);

    // 1. Outgoing Transaction (Expense from source currency)
    final outTx = TransactionModel(
      id: outId,
      title: 'تحويل إلى ${toCurrency.nameAr}',
      amount: fromAmount,
      currency: fromCurrency,
      type: TransactionType.expense,
      categoryId: 'exchange_transfer',
      categoryName: 'صرافة وتحويل',
      categoryIconCode: 0xe1be, // Icons.currency_exchange
      categoryColorValue: 0xFF0284C7, // Sky Blue
      date: date,
      notes: notes != null && notes.isNotEmpty
          ? '$notes (سعر الصرف: $exchangeRate)'
          : 'سعر الصرف: $exchangeRate ${toCurrency.symbol} لكل 1 ${fromCurrency.symbol}',
      walletId: targetWalletId,
      isTransfer: 1,
      transferId: transferId,
      exchangeRate: exchangeRate,
      targetCurrency: toCurrency,
      targetAmount: toAmount,
    );

    // 2. Incoming Transaction (Income into destination currency)
    final inTx = TransactionModel(
      id: inId,
      title: 'استلام تحويل من ${fromCurrency.nameAr}',
      amount: toAmount,
      currency: toCurrency,
      type: TransactionType.income,
      categoryId: 'exchange_transfer',
      categoryName: 'صرافة وتحويل',
      categoryIconCode: 0xe1be, // Icons.currency_exchange
      categoryColorValue: 0xFF0284C7, // Sky Blue
      date: date,
      notes: notes != null && notes.isNotEmpty
          ? '$notes (من مبلغ: $fromAmount ${fromCurrency.symbol})'
          : 'مقابل $fromAmount ${fromCurrency.symbol} بسعر صرف $exchangeRate',
      walletId: targetWalletId,
      isTransfer: 1,
      transferId: transferId,
      exchangeRate: exchangeRate,
      targetCurrency: fromCurrency,
      targetAmount: fromAmount,
    );

    // Save both atomically via SQLite transaction
    await _dbHelper.runTransaction((txn) async {
      await _dbHelper.insertTransaction(outTx, txn: txn);
      await _dbHelper.insertTransaction(inTx, txn: txn);
    });

    _transactions.insert(0, outTx);
    _transactions.insert(0, inTx);
    _transactions.sort((a, b) => b.date.compareTo(a.date));

    notifyListeners();
  }

  /// Deletes both parts of a linked transfer pair
  Future<void> deleteTransferPair(String transferId) async {
    final toDelete = _transactions.where((t) => t.transferId == transferId).toList();
    for (final tx in toDelete) {
      await _dbHelper.deleteTransaction(tx.id);
    }
    _transactions.removeWhere((t) => t.transferId == transferId);
    notifyListeners();
  }

  // ================= Wallets Management (Phase 5) =================

  Future<WalletModel> addWallet(
    String name, {
    int? iconCode,
    int? colorValue,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('اسم المحفظة لا يمكن أن يكون فارغاً');
    }
    final newWallet = WalletModel(
      name: trimmed,
      iconCode: iconCode ?? 0xf534,
      colorValue: colorValue ?? 0xFF0D9488,
    );
    final id = await _dbHelper.insertWallet(newWallet);
    final created = newWallet.copyWith(id: id);
    _wallets.add(created);
    notifyListeners();
    return created;
  }

  Future<void> updateWallet(WalletModel wallet) async {
    await _dbHelper.updateWallet(wallet);
    final index = _wallets.indexWhere((w) => w.id == wallet.id);
    if (index != -1) {
      _wallets[index] = wallet;
      notifyListeners();
    }
  }

  Future<void> deleteWallet(int id) async {
    if (_wallets.length <= 1) {
      throw Exception('لا يمكن حذف المحفظة الوحيدة المتبقية في التطبيق');
    }
    await _dbHelper.deleteWallet(id);
    _wallets.removeWhere((w) => w.id == id);
    notifyListeners();
  }

  WalletModel? findWalletById(int? id) {
    if (id == null) return null;
    try {
      return _wallets.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Calculates net balance for a specific wallet and currency
  double getWalletBalance(int walletId, AppCurrency currency) {
    final income = _transactions
        .where((t) => t.walletId == walletId && t.currency == currency && t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
    final expense = _transactions
        .where((t) => t.walletId == walletId && t.currency == currency && t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
    return income - expense;
  }

  /// Returns multi-currency balances for a specific wallet, filtering out zero balances
  Map<AppCurrency, double> getWalletBalances(int walletId) {
    final balances = <AppCurrency, double>{};
    for (final currency in AppCurrency.values) {
      final bal = getWalletBalance(walletId, currency);
      if (bal != 0.0) {
        balances[currency] = bal;
      }
    }
    return balances;
  }

  /// Executes an atomic wallet-to-wallet transfer in SQLite
  Future<void> transferFunds({
    required int fromWalletId,
    required int toWalletId,
    required double amount,
    required dynamic currency,
    String? note,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('المبلغ يجب أن يكون أكبر من الصفر');
    }
    if (fromWalletId == toWalletId) {
      throw ArgumentError('لا يمكن التحويل لنفس المحفظة');
    }

    final AppCurrency appCurrency = currency is AppCurrency
        ? currency
        : AppCurrency.fromCode(currency.toString());

    final fromWallet = _wallets.firstWhere(
      (w) => w.id == fromWalletId,
      orElse: () => WalletModel(id: fromWalletId, name: 'محفظة $fromWalletId'),
    );
    final toWallet = _wallets.firstWhere(
      (w) => w.id == toWalletId,
      orElse: () => WalletModel(id: toWalletId, name: 'محفظة $toWalletId'),
    );

    final transferId = 'wallet_transfer_${const Uuid().v4()}';
    final now = DateTime.now();

    // 1. Outgoing Transaction (Expense from source wallet)
    final outTx = TransactionModel(
      id: const Uuid().v4(),
      title: 'تحويل إلى ${toWallet.name}',
      amount: amount,
      currency: appCurrency,
      type: TransactionType.expense,
      categoryId: 'wallet_transfer',
      categoryName: 'تحويل بين المحافظ',
      categoryIconCode: 0xe1be, // Icons.currency_exchange
      categoryColorValue: 0xFF0284C7, // Sky Blue
      date: now,
      notes: note != null && note.isNotEmpty ? note : 'تحويل من ${fromWallet.name} إلى ${toWallet.name}',
      walletId: fromWalletId,
      isTransfer: 1,
      transferId: transferId,
    );

    // 2. Incoming Transaction (Income into destination wallet)
    final inTx = TransactionModel(
      id: const Uuid().v4(),
      title: 'استلام تحويل من ${fromWallet.name}',
      amount: amount,
      currency: appCurrency,
      type: TransactionType.income,
      categoryId: 'wallet_transfer',
      categoryName: 'تحويل بين المحافظ',
      categoryIconCode: 0xe1be,
      categoryColorValue: 0xFF0284C7,
      date: now,
      notes: note != null && note.isNotEmpty ? note : 'استلام من ${fromWallet.name}',
      walletId: toWalletId,
      isTransfer: 1,
      transferId: transferId,
    );

    // Execute both inserts atomically inside SQLite transaction
    await _dbHelper.runTransaction((txn) async {
      await _dbHelper.insertTransaction(outTx, txn: txn);
      await _dbHelper.insertTransaction(inTx, txn: txn);
    });

    _transactions.insert(0, outTx);
    _transactions.insert(0, inTx);
    _transactions.sort((a, b) => b.date.compareTo(a.date));

    notifyListeners();
  }

  // ================= Recurring Transactions =================

  Future<void> addRecurringTransaction(RecurringTransactionModel model) async {
    await _dbHelper.insertRecurring(model);
    _recurringTransactions.add(model);
    _recurringTransactions.sort((a, b) => a.dayOfMonth.compareTo(b.dayOfMonth));
    notifyListeners();
  }

  Future<void> updateRecurringTransaction(RecurringTransactionModel model) async {
    await _dbHelper.updateRecurring(model);
    final index = _recurringTransactions.indexWhere((r) => r.id == model.id);
    if (index != -1) {
      _recurringTransactions[index] = model;
      _recurringTransactions.sort((a, b) => a.dayOfMonth.compareTo(b.dayOfMonth));
      notifyListeners();
    }
  }

  Future<void> deleteRecurringTransaction(String id) async {
    await _dbHelper.deleteRecurring(id);
    _recurringTransactions.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  Future<void> toggleRecurringActive(String id, bool isActive) async {
    final index = _recurringTransactions.indexWhere((r) => r.id == id);
    if (index != -1) {
      final updated = _recurringTransactions[index].copyWith(isActive: isActive);
      await _dbHelper.updateRecurring(updated);
      _recurringTransactions[index] = updated;
      notifyListeners();
    }
  }

  /// Evaluates and processes due recurring transactions upon App Startup
  Future<int> processDueRecurringTransactions() async {
    final now = DateTime.now();
    int processedCount = 0;
    final defaultWalletId = _wallets.isNotEmpty ? _wallets.first.id : 1;

    for (int i = 0; i < _recurringTransactions.length; i++) {
      final recurring = _recurringTransactions[i];
      if (!recurring.isActive) continue;

      // Check if already processed in current month and year
      final lastDate = recurring.lastProcessedDate;
      final alreadyProcessedThisMonth = lastDate != null &&
          lastDate.year == now.year &&
          lastDate.month == now.month;

      // Check if due day has arrived
      if (!alreadyProcessedThisMonth && now.day >= recurring.dayOfMonth) {
        final txDate = DateTime(now.year, now.month, recurring.dayOfMonth);

        final newTx = TransactionModel(
          id: const Uuid().v4(),
          title: recurring.title,
          amount: recurring.amount,
          currency: recurring.currency,
          type: recurring.type,
          categoryId: recurring.categoryId,
          categoryName: recurring.categoryName,
          categoryIconCode: recurring.categoryIconCode,
          categoryColorValue: recurring.categoryColorValue,
          date: txDate,
          notes: (recurring.notes != null && recurring.notes!.isNotEmpty)
              ? '${recurring.notes} (عملية متكررة مجدولة لشهر ${now.month})'
              : 'عملية متكررة مجدولة تلقائياً لشهر ${now.month}',
          isRecurring: true,
          recurringId: recurring.id,
          walletId: defaultWalletId,
          isTransfer: 0,
        );

        await _dbHelper.insertTransaction(newTx);
        _transactions.insert(0, newTx);

        // Update last processed date
        final updatedRecurring = recurring.copyWith(lastProcessedDate: now);
        await _dbHelper.updateRecurring(updatedRecurring);
        _recurringTransactions[i] = updatedRecurring;

        processedCount++;
      }
    }

    if (processedCount > 0) {
      _transactions.sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();
    }

    return processedCount;
  }

  // ================= Currency Calculations (Grand Total Across All Wallets) =================

  /// Total Income for a given currency across ALL wallets (excluding internal wallet transfers)
  double getTotalIncome(AppCurrency currency) {
    return _transactions
        .where((t) => t.currency == currency && t.type == TransactionType.income && !t.isWalletTransfer)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Total Expense for a given currency across ALL wallets (excluding internal wallet transfers)
  double getTotalExpense(AppCurrency currency) {
    return _transactions
        .where((t) => t.currency == currency && t.type == TransactionType.expense && !t.isWalletTransfer)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Total Net Balance for a given currency across ALL wallets (Income - Expense)
  double getTotalBalance(AppCurrency currency) {
    final income = getTotalIncome(currency);
    final expense = getTotalExpense(currency);
    return income - expense;
  }

  /// Monthly Expense for a given currency (excluding internal wallet transfers)
  double getMonthlyExpense(AppCurrency currency, {DateTime? month}) {
    final target = month ?? DateTime.now();
    return _transactions
        .where((t) =>
            t.currency == currency &&
            t.type == TransactionType.expense &&
            !t.isWalletTransfer &&
            t.date.year == target.year &&
            t.date.month == target.month)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Monthly Income for a given currency (excluding internal wallet transfers)
  double getMonthlyIncome(AppCurrency currency, {DateTime? month}) {
    final target = month ?? DateTime.now();
    return _transactions
        .where((t) =>
            t.currency == currency &&
            t.type == TransactionType.income &&
            !t.isWalletTransfer &&
            t.date.year == target.year &&
            t.date.month == target.month)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Monthly Spending on a specific category for a given currency
  double getCategoryMonthlySpending(
    String categoryId,
    AppCurrency currency, {
    DateTime? month,
  }) {
    final target = month ?? DateTime.now();
    return _transactions
        .where((t) =>
            t.categoryId == categoryId &&
            t.currency == currency &&
            t.type == TransactionType.expense &&
            !t.isWalletTransfer &&
            t.date.year == target.year &&
            t.date.month == target.month)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // ================= Query & Filter Helpers =================

  List<TransactionModel> getRecentTransactions({int limit = 6}) {
    if (_transactions.length <= limit) return _transactions;
    return _transactions.sublist(0, limit);
  }

  List<TransactionModel> filterTransactions({
    AppCurrency? currency,
    TransactionType? type,
    String? categoryId,
    int? walletId,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
    bool? isWalletTransfer,
  }) {
    return _transactions.where((t) {
      if (currency != null && t.currency != currency) return false;
      if (isWalletTransfer != null && t.isWalletTransfer != isWalletTransfer) return false;
      if (type != null && t.type != type) return false;
      if (categoryId != null && t.categoryId != categoryId) return false;
      if (walletId != null && t.walletId != walletId) return false;
      if (startDate != null && t.date.isBefore(DateTime(startDate.year, startDate.month, startDate.day))) return false;
      if (endDate != null && t.date.isAfter(DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59))) return false;
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final query = searchQuery.trim().toLowerCase();
        final matchesTitle = t.title.toLowerCase().contains(query);
        final matchesCategory = t.categoryName.toLowerCase().contains(query);
        final matchesNotes = t.notes?.toLowerCase().contains(query) ?? false;
        if (!matchesTitle && !matchesCategory && !matchesNotes) return false;
      }
      return true;
    }).toList();
  }
}
