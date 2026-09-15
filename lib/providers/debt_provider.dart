import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/debt_model.dart';
import '../models/debt_payment_model.dart';
import '../models/person_model.dart';
import '../models/app_currency.dart';
import '../services/database_helper.dart';

class DebtProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper;
  List<DebtModel> _debts = [];
  List<PersonModel> _persons = [];
  bool _isLoading = false;

  DebtProvider({DatabaseHelper? dbHelper, dynamic dbService})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance {
    loadAll();
  }

  bool get isLoading => _isLoading;
  List<DebtModel> get debts => List.unmodifiable(_debts);
  List<PersonModel> get persons => List.unmodifiable(_persons);

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();
    try {
      await Future.wait([
        loadPersons(notify: false),
        loadDebts(notify: false),
      ]);
    } catch (e) {
      debugPrint('[DebtProvider] Error loading debts and persons: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDebts({bool notify = true}) async {
    _debts = await _dbHelper.getAllDebts();
    if (notify) notifyListeners();
  }

  Future<void> loadPersons({bool notify = true}) async {
    _persons = await _dbHelper.getAllPersons();
    _persons.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (notify) notifyListeners();
  }

  // ================= Persons CRUD =================

  Future<PersonModel> addPerson({
    required String name,
    String? phone,
    String? notes,
  }) async {
    final person = PersonModel(
      id: 'person_${const Uuid().v4()}',
      name: name.trim(),
      phone: (phone != null && phone.trim().isNotEmpty) ? phone.trim() : null,
      notes: (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
    );
    await _dbHelper.insertPerson(person);
    _persons.add(person);
    _persons.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    notifyListeners();
    return person;
  }

  Future<void> updatePerson(PersonModel person) async {
    await _dbHelper.updatePerson(person);
    final index = _persons.indexWhere((p) => p.id == person.id);
    if (index != -1) {
      _persons[index] = person;
      _persons.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    // Also update cached personName and phone on his debts
    for (int i = 0; i < _debts.length; i++) {
      if (_debts[i].personId == person.id) {
        final updatedDebt = _debts[i].copyWith(
          personName: person.name,
          phone: person.phone,
        );
        await _dbHelper.updateDebt(updatedDebt);
        _debts[i] = updatedDebt;
      }
    }
    notifyListeners();
  }

  Future<void> deletePerson(String personId) async {
    await _dbHelper.deletePerson(personId);
    _persons.removeWhere((p) => p.id == personId);
    notifyListeners();
  }

  PersonModel? findPersonById(String? id) {
    if (id == null) return null;
    try {
      return _persons.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  PersonModel? findPersonByName(String name) {
    try {
      return _persons.firstWhere(
        (p) => p.name.trim().toLowerCase() == name.trim().toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  // ================= Debts CRUD =================

  Future<void> addDebt(DebtModel debt) async {
    // If personId is provided, ensure person is up to date
    if (debt.personId != null) {
      final p = findPersonById(debt.personId);
      if (p != null) {
        debt = debt.copyWith(personName: p.name, phone: p.phone ?? debt.phone);
      }
    } else {
      // Find or create person by name
      PersonModel? p = findPersonByName(debt.personName);
      p ??= await addPerson(name: debt.personName, phone: debt.phone);
      debt = debt.copyWith(personId: p.id, personName: p.name);
    }

    await _dbHelper.insertDebt(debt);
    _debts.insert(0, debt);
    notifyListeners();
  }

  Future<void> updateDebt(DebtModel debt) async {
    if (debt.personId != null) {
      final p = findPersonById(debt.personId);
      if (p != null) {
        debt = debt.copyWith(personName: p.name, phone: p.phone ?? debt.phone);
      }
    }
    await _dbHelper.updateDebt(debt);
    final index = _debts.indexWhere((d) => d.id == debt.id);
    if (index != -1) {
      _debts[index] = debt;
      notifyListeners();
    }
  }

  Future<void> deleteDebt(String id) async {
    await _dbHelper.deleteDebt(id);
    _debts.removeWhere((d) => d.id == id);
    notifyListeners();
  }

  DebtModel? findDebtById(String id) {
    try {
      return _debts.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Records a partial or full payment for a specific debt
  Future<DebtModel?> recordPayment({
    required String debtId,
    required double amount,
    required DateTime date,
    String? note,
    bool impactsBalance = false,
  }) async {
    final index = _debts.indexWhere((d) => d.id == debtId);
    if (index == -1) return null;

    final debt = _debts[index];
    final payment = DebtPaymentModel(
      id: 'pay_${DateTime.now().millisecondsSinceEpoch}',
      debtId: debtId,
      amount: amount,
      date: date,
      note: note,
      impactsBalance: impactsBalance,
    );

    final updatedPayments = List<DebtPaymentModel>.from(debt.payments)..add(payment);
    final updatedDebt = debt.copyWith(payments: updatedPayments);

    await updateDebt(updatedDebt);
    return updatedDebt;
  }

  // ================= Person Ledger Calculations =================

  /// All debts belonging to a specific Person (by personId or matching personName)
  List<DebtModel> getDebtsForPerson(String personId) {
    final person = findPersonById(personId);
    return _debts.where((d) {
      if (d.personId == personId) return true;
      if (person != null && d.personName.trim().toLowerCase() == person.name.trim().toLowerCase()) {
        return true;
      }
      return false;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// All payment records across all debts for a specific Person
  List<DebtPaymentModel> getAllPaymentsForPerson(String personId) {
    final debts = getDebtsForPerson(personId);
    final allPayments = <DebtPaymentModel>[];
    for (var d in debts) {
      allPayments.addAll(d.payments);
    }
    allPayments.sort((a, b) => b.date.compareTo(a.date));
    return allPayments;
  }

  /// Total remaining amount due to me (عليه / دين لي) for a specific Person and Currency
  double getRemainingLentForPerson(String personId, AppCurrency currency) {
    return getDebtsForPerson(personId)
        .where((d) => d.currency == currency && d.type == DebtType.forMe)
        .fold(0.0, (sum, d) => sum + d.remainingAmount);
  }

  /// Total remaining amount owed by me (له / دين علي) for a specific Person and Currency
  double getRemainingBorrowedForPerson(String personId, AppCurrency currency) {
    return getDebtsForPerson(personId)
        .where((d) => d.currency == currency && d.type == DebtType.onMe)
        .fold(0.0, (sum, d) => sum + d.remainingAmount);
  }

  /// Net balance for a Person in a specific Currency (Lent - Borrowed)
  double getNetBalanceForPerson(String personId, AppCurrency currency) {
    final lent = getRemainingLentForPerson(personId, currency);
    final borrowed = getRemainingBorrowedForPerson(personId, currency);
    return lent - borrowed;
  }

  // ================= Global Currency Calculations =================

  /// Total Initial Amount of "دين لي" (Lent / Due to me)
  double getTotalLent(AppCurrency currency) {
    return _debts
        .where((d) => d.currency == currency && d.type == DebtType.forMe)
        .fold(0.0, (sum, d) => sum + d.totalAmount);
  }

  /// Total Remaining Unpaid "دين لي" (Lent / Due to me)
  double getRemainingLent(AppCurrency currency) {
    return _debts
        .where((d) => d.currency == currency && d.type == DebtType.forMe)
        .fold(0.0, (sum, d) => sum + d.remainingAmount);
  }

  /// Total Initial Amount of "دين علي" (Borrowed / Owed by me)
  double getTotalBorrowed(AppCurrency currency) {
    return _debts
        .where((d) => d.currency == currency && d.type == DebtType.onMe)
        .fold(0.0, (sum, d) => sum + d.totalAmount);
  }

  /// Total Remaining Unpaid "دين علي" (Borrowed / Owed by me)
  double getRemainingBorrowed(AppCurrency currency) {
    return _debts
        .where((d) => d.currency == currency && d.type == DebtType.onMe)
        .fold(0.0, (sum, d) => sum + d.remainingAmount);
  }

  /// Net Debt Balance (Due to me - Owed by me)
  double getNetDebtBalance(AppCurrency currency) {
    return getRemainingLent(currency) - getRemainingBorrowed(currency);
  }

  /// Total number of active/unsettled debts for a specific Currency
  int getUnsettledDebtsCount(AppCurrency currency) {
    return _debts.where((d) => d.currency == currency && !d.isFullyPaid).length;
  }

  DebtModel? findById(String id) => findDebtById(id);

  List<PersonModel> filterPersons(String? query) {
    if (query == null || query.trim().isEmpty) return _persons;
    final q = query.trim().toLowerCase();
    return _persons.where((p) {
      final matchesName = p.name.toLowerCase().contains(q);
      final matchesPhone = p.phone?.toLowerCase().contains(q) ?? false;
      final matchesNotes = p.notes?.toLowerCase().contains(q) ?? false;
      return matchesName || matchesPhone || matchesNotes;
    }).toList();
  }

  List<DebtModel> filterDebts({
    AppCurrency? currency,
    DebtType? type,
    bool? isSettled,
    String? searchQuery,
  }) {
    return _debts.where((d) {
      if (currency != null && d.currency != currency) return false;
      if (type != null && d.type != type) return false;
      if (isSettled != null && d.isSettled != isSettled) return false;
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        final matchesPerson = d.personName.toLowerCase().contains(q);
        final matchesNotes = d.notes?.toLowerCase().contains(q) ?? false;
        final matchesPhone = d.phone?.toLowerCase().contains(q) ?? false;
        if (!matchesPerson && !matchesNotes && !matchesPhone) return false;
      }
      return true;
    }).toList();
  }
}
