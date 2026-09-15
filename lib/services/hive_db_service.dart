import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../models/debt_model.dart';
import '../models/category_model.dart';
import '../models/recurring_transaction_model.dart';
import '../models/person_model.dart';

class HiveDbService {
  static const String _transactionsBoxName = 'transactions_box';
  static const String _debtsBoxName = 'debts_box';
  static const String _categoriesBoxName = 'categories_box';
  static const String _settingsBoxName = 'settings_box';
  static const String _recurringBoxName = 'recurring_transactions_box';
  static const String _personsBoxName = 'persons_box';

  late Box _transactionsBox;
  late Box _debtsBox;
  late Box _categoriesBox;
  late Box _settingsBox;
  late Box _recurringBox;
  late Box _personsBox;

  static final HiveDbService _instance = HiveDbService._internal();
  factory HiveDbService() => _instance;
  HiveDbService._internal();

  /// Initialize Hive and open all required boxes
  Future<void> init() async {
    await Hive.initFlutter();

    _transactionsBox = await Hive.openBox(_transactionsBoxName);
    _debtsBox = await Hive.openBox(_debtsBoxName);
    _categoriesBox = await Hive.openBox(_categoriesBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
    _recurringBox = await Hive.openBox(_recurringBoxName);
    _personsBox = await Hive.openBox(_personsBoxName);

    await _seedDefaultCategoriesIfNeeded();
    await _migratePersonsFromLegacyDebtsIfNeeded();
  }

  /// Seed initial categories if categories box is empty
  Future<void> _seedDefaultCategoriesIfNeeded() async {
    if (_categoriesBox.isEmpty) {
      for (final cat in CategoryModel.defaultCategories) {
        await _categoriesBox.put(cat.id, cat.toMap());
      }
      debugPrint('Default categories seeded successfully (${_categoriesBox.length} categories)');
    }
  }

  /// Automatically creates Person records from existing legacy debts if personsBox is empty
  Future<void> _migratePersonsFromLegacyDebtsIfNeeded() async {
    try {
      final debts = getAllDebts();
      if (debts.isEmpty) return;

      final existingPersons = getAllPersons();
      final Map<String, PersonModel> personByName = {
        for (var p in existingPersons) p.name.trim().toLowerCase(): p
      };

      bool updatedAnyDebt = false;

      for (var debt in debts) {
        final normName = debt.personName.trim().toLowerCase();
        if (normName.isEmpty) continue;

        PersonModel person;
        if (personByName.containsKey(normName)) {
          person = personByName[normName]!;
        } else {
          final newPersonId = 'person_${const Uuid().v4()}';
          person = PersonModel(
            id: newPersonId,
            name: debt.personName.trim(),
            phone: debt.phone,
            createdAt: debt.createdAt,
          );
          await savePerson(person);
          personByName[normName] = person;
        }

        if (debt.personId == null || debt.personId != person.id) {
          final updatedDebt = debt.copyWith(
            personId: person.id,
            personName: person.name,
            phone: person.phone ?? debt.phone,
          );
          await saveDebt(updatedDebt);
          updatedAnyDebt = true;
        }
      }

      if (updatedAnyDebt) {
        debugPrint('Legacy debts successfully migrated and linked to Persons Ledger!');
      }
    } catch (e) {
      debugPrint('Error during persons migration: $e');
    }
  }

  // ================= Persons CRUD =================
  List<PersonModel> getAllPersons() {
    try {
      final list = <PersonModel>[];
      for (var key in _personsBox.keys) {
        final raw = _personsBox.get(key);
        if (raw is Map) {
          list.add(PersonModel.fromMap(raw));
        }
      }
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    } catch (e) {
      debugPrint('Error getting persons: $e');
      return [];
    }
  }

  Future<void> savePerson(PersonModel person) async {
    await _personsBox.put(person.id, person.toMap());
  }

  Future<void> deletePerson(String id) async {
    await _personsBox.delete(id);
  }

  // ================= Transactions CRUD =================
  List<TransactionModel> getAllTransactions() {
    try {
      final list = <TransactionModel>[];
      for (var key in _transactionsBox.keys) {
        final raw = _transactionsBox.get(key);
        if (raw is Map) {
          list.add(TransactionModel.fromMap(raw));
        }
      }
      list.sort((a, b) => b.date.compareTo(a.date)); // Sort by date descending
      return list;
    } catch (e) {
      debugPrint('Error getting transactions: $e');
      return [];
    }
  }

  Future<void> saveTransaction(TransactionModel transaction) async {
    await _transactionsBox.put(transaction.id, transaction.toMap());
  }

  Future<void> deleteTransaction(String id) async {
    await _transactionsBox.delete(id);
  }

  // ================= Recurring Transactions CRUD =================
  List<RecurringTransactionModel> getAllRecurring() {
    try {
      final list = <RecurringTransactionModel>[];
      for (var key in _recurringBox.keys) {
        final raw = _recurringBox.get(key);
        if (raw is Map) {
          list.add(RecurringTransactionModel.fromMap(raw));
        }
      }
      list.sort((a, b) => a.dayOfMonth.compareTo(b.dayOfMonth));
      return list;
    } catch (e) {
      debugPrint('Error getting recurring transactions: $e');
      return [];
    }
  }

  Future<void> saveRecurring(RecurringTransactionModel recurring) async {
    await _recurringBox.put(recurring.id, recurring.toMap());
  }

  Future<void> deleteRecurring(String id) async {
    await _recurringBox.delete(id);
  }

  // ================= Debts CRUD =================
  List<DebtModel> getAllDebts() {
    try {
      final list = <DebtModel>[];
      for (var key in _debtsBox.keys) {
        final raw = _debtsBox.get(key);
        if (raw is Map) {
          list.add(DebtModel.fromMap(raw));
        }
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      debugPrint('Error getting debts: $e');
      return [];
    }
  }

  Future<void> saveDebt(DebtModel debt) async {
    await _debtsBox.put(debt.id, debt.toMap());
  }

  Future<void> deleteDebt(String id) async {
    await _debtsBox.delete(id);
  }

  // ================= Categories CRUD =================
  List<CategoryModel> getAllCategories() {
    try {
      final list = <CategoryModel>[];
      for (var key in _categoriesBox.keys) {
        final raw = _categoriesBox.get(key);
        if (raw is Map) {
          list.add(CategoryModel.fromMap(raw));
        }
      }
      return list;
    } catch (e) {
      debugPrint('Error getting categories: $e');
      return CategoryModel.defaultCategories;
    }
  }

  Future<void> saveCategory(CategoryModel category) async {
    await _categoriesBox.put(category.id, category.toMap());
  }

  Future<void> deleteCategory(String id) async {
    await _categoriesBox.delete(id);
  }

  // ================= Settings & Flags =================
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return _settingsBox.get(key, defaultValue: defaultValue);
  }

  Future<void> setSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  Future<void> removeSetting(String key) async {
    await _settingsBox.delete(key);
  }

  // ================= Bulk Operations =================
  Future<void> clearAllData() async {
    await _transactionsBox.clear();
    await _debtsBox.clear();
    await _categoriesBox.clear();
    await _recurringBox.clear();
    await _personsBox.clear();
    await _seedDefaultCategoriesIfNeeded();
  }

  Future<void> restoreAll({
    required List<TransactionModel> transactions,
    required List<DebtModel> debts,
    required List<CategoryModel> categories,
    List<PersonModel>? persons,
  }) async {
    await _transactionsBox.clear();
    for (final t in transactions) {
      await _transactionsBox.put(t.id, t.toMap());
    }

    await _debtsBox.clear();
    for (final d in debts) {
      await _debtsBox.put(d.id, d.toMap());
    }

    if (categories.isNotEmpty) {
      await _categoriesBox.clear();
      for (final c in categories) {
        await _categoriesBox.put(c.id, c.toMap());
      }
    }

    if (persons != null && persons.isNotEmpty) {
      await _personsBox.clear();
      for (final p in persons) {
        await _personsBox.put(p.id, p.toMap());
      }
    }
  }
}
