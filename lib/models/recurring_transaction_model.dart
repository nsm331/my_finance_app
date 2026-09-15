import 'app_currency.dart';
import 'transaction_model.dart';

class RecurringTransactionModel {
  final String id;
  final String title;
  final double amount;
  final AppCurrency currency;
  final TransactionType type;
  final String categoryId;
  final String categoryName;
  final int categoryIconCode;
  final int categoryColorValue;
  final int dayOfMonth; // 1 - 31
  final DateTime startDate;
  final DateTime? lastProcessedDate;
  final bool isActive;
  final String? notes;
  final DateTime createdAt;

  RecurringTransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.currency,
    required this.type,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIconCode,
    required this.categoryColorValue,
    required this.dayOfMonth,
    required this.startDate,
    this.lastProcessedDate,
    this.isActive = true,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'currency': currency.code,
      'type': type.name,
      'category_id': categoryId,
      'category_name': categoryName,
      'category_icon_code': categoryIconCode,
      'category_color_value': categoryColorValue,
      'day_of_month': dayOfMonth,
      'start_date': startDate.toIso8601String(),
      'last_processed_date': lastProcessedDate?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      // Backward compatibility keys
      'categoryId': categoryId,
      'categoryName': categoryName,
      'categoryIconCode': categoryIconCode,
      'categoryColorValue': categoryColorValue,
      'dayOfMonth': dayOfMonth,
      'startDate': startDate.toIso8601String(),
      'lastProcessedDate': lastProcessedDate?.toIso8601String(),
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory RecurringTransactionModel.fromMap(Map<dynamic, dynamic> map) {
    bool parseBool(dynamic val, bool defaultVal) {
      if (val is bool) return val;
      if (val is int) return val == 1;
      return defaultVal;
    }

    return RecurringTransactionModel(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      amount: (map['amount'] as num).toDouble(),
      currency: AppCurrencyExtension.fromString(map['currency'] as String?),
      type: TransactionTypeExtension.fromString(map['type'] as String?),
      categoryId: (map['category_id'] ?? map['categoryId']) as String? ?? 'general',
      categoryName: (map['category_name'] ?? map['categoryName']) as String? ?? 'عام',
      categoryIconCode: (map['category_icon_code'] ?? map['categoryIconCode']) as int? ?? 0xe5d8,
      categoryColorValue: (map['category_color_value'] ?? map['categoryColorValue']) as int? ?? 0xFF0D9488,
      dayOfMonth: ((map['day_of_month'] ?? map['dayOfMonth']) as int?) ?? 1,
      startDate: DateTime.tryParse((map['start_date'] ?? map['startDate']) as String? ?? '') ?? DateTime.now(),
      lastProcessedDate: (map['last_processed_date'] ?? map['lastProcessedDate']) != null
          ? DateTime.tryParse((map['last_processed_date'] ?? map['lastProcessedDate']) as String)
          : null,
      isActive: parseBool(map['is_active'] ?? map['isActive'], true),
      notes: map['notes'] as String?,
      createdAt: DateTime.tryParse((map['created_at'] ?? map['createdAt']) as String? ?? '') ?? DateTime.now(),
    );
  }

  RecurringTransactionModel copyWith({
    String? id,
    String? title,
    double? amount,
    AppCurrency? currency,
    TransactionType? type,
    String? categoryId,
    String? categoryName,
    int? categoryIconCode,
    int? categoryColorValue,
    int? dayOfMonth,
    DateTime? startDate,
    DateTime? lastProcessedDate,
    bool? isActive,
    String? notes,
    DateTime? createdAt,
  }) {
    return RecurringTransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryIconCode: categoryIconCode ?? this.categoryIconCode,
      categoryColorValue: categoryColorValue ?? this.categoryColorValue,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      startDate: startDate ?? this.startDate,
      lastProcessedDate: lastProcessedDate ?? this.lastProcessedDate,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
