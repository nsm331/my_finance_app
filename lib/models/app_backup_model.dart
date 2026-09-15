import 'transaction_model.dart';
import 'debt_model.dart';
import 'category_model.dart';
import 'person_model.dart';

class AppBackupModel {
  final int version;
  final String exportedAt;
  final List<TransactionModel> transactions;
  final List<DebtModel> debts;
  final List<CategoryModel> categories;
  final List<PersonModel> persons;
  final Map<String, dynamic> metadata;

  AppBackupModel({
    this.version = 2,
    required this.exportedAt,
    required this.transactions,
    required this.debts,
    required this.categories,
    List<PersonModel>? persons,
    Map<String, dynamic>? metadata,
  })  : persons = persons ?? [],
        metadata = metadata ?? {};

  Map<String, dynamic> toJson() {
    return {
      'app': 'MyFinanceApp',
      'version': version,
      'exportedAt': exportedAt,
      'transactionsCount': transactions.length,
      'debtsCount': debts.length,
      'categoriesCount': categories.length,
      'personsCount': persons.length,
      'metadata': metadata,
      'transactions': transactions.map((t) => t.toMap()).toList(),
      'debts': debts.map((d) => d.toMap()).toList(),
      'categories': categories.map((c) => c.toMap()).toList(),
      'persons': persons.map((p) => p.toMap()).toList(),
    };
  }

  factory AppBackupModel.fromJson(Map<String, dynamic> json) {
    final rawTransactions = json['transactions'] as List<dynamic>? ?? [];
    final rawDebts = json['debts'] as List<dynamic>? ?? [];
    final rawCategories = json['categories'] as List<dynamic>? ?? [];
    final rawPersons = json['persons'] as List<dynamic>? ?? [];

    return AppBackupModel(
      version: json['version'] as int? ?? 1,
      exportedAt: json['exportedAt'] as String? ?? DateTime.now().toIso8601String(),
      transactions: rawTransactions
          .map((t) => TransactionModel.fromMap(t as Map<dynamic, dynamic>))
          .toList(),
      debts: rawDebts
          .map((d) => DebtModel.fromMap(d as Map<dynamic, dynamic>))
          .toList(),
      categories: rawCategories
          .map((c) => CategoryModel.fromMap(c as Map<dynamic, dynamic>))
          .toList(),
      persons: rawPersons
          .map((p) => PersonModel.fromMap(p as Map<dynamic, dynamic>))
          .toList(),
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : {},
    );
  }
}
