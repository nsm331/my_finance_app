import 'app_currency.dart';

enum TransactionType {
  income,  // دخل
  expense, // مصروف
}

extension TransactionTypeExtension on TransactionType {
  String get nameAr {
    switch (this) {
      case TransactionType.income:
        return 'دخل';
      case TransactionType.expense:
        return 'مصروف';
    }
  }

  static TransactionType fromString(String? val) {
    if (val == 'income') return TransactionType.income;
    return TransactionType.expense;
  }
}

class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final AppCurrency currency;
  final TransactionType type;
  final String categoryId;
  final String categoryName;
  final int categoryIconCode;
  final int categoryColorValue;
  final DateTime date;
  final String? notes;
  final DateTime createdAt;

  // Wallet
  final int? walletId;

  // Transfer flag (0: regular transaction, 1: transfer between wallets or exchange)
  final int isTransfer;

  // Currency Transfer & Exchange properties
  final String? transferId;
  final double? exchangeRate;
  final AppCurrency? targetCurrency;
  final double? targetAmount;

  // Recurring properties
  final bool isRecurring;
  final String? recurringId;

  TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.currency,
    required this.type,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIconCode,
    required this.categoryColorValue,
    required this.date,
    this.notes,
    DateTime? createdAt,
    this.walletId,
    this.isTransfer = 0,
    this.transferId,
    this.exchangeRate,
    this.targetCurrency,
    this.targetAmount,
    this.isRecurring = false,
    this.recurringId,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isTransferBool => isTransfer == 1;
  bool get isWalletTransfer => isTransfer == 1 && (categoryId == 'wallet_transfer' || (transferId != null && transferId!.startsWith('wallet_transfer_')));
  bool get isCurrencyExchange => isTransfer == 1 && (categoryId == 'exchange_transfer' || (transferId != null && !isWalletTransfer));

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
      'date': date.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'wallet_id': walletId,
      'isTransfer': isTransfer,
      'transfer_id': transferId,
      'exchange_rate': exchangeRate,
      'target_currency': targetCurrency?.code,
      'target_amount': targetAmount,
      'is_recurring': isRecurring ? 1 : 0,
      'recurring_id': recurringId,
    };
  }

  factory TransactionModel.fromMap(Map<dynamic, dynamic> map) {
    final walletId = (map['wallet_id'] ?? map['walletId']) as int?;

    int parsedIsTransfer = 0;
    final rawTransfer = map['isTransfer'] ?? map['is_transfer'];
    if (rawTransfer is int) {
      parsedIsTransfer = rawTransfer;
    } else if (rawTransfer is bool) {
      parsedIsTransfer = rawTransfer ? 1 : 0;
    }

    bool parsedIsRecurring = false;
    final rawRecurring = map['is_recurring'] ?? map['isRecurring'];
    if (rawRecurring is bool) {
      parsedIsRecurring = rawRecurring;
    } else if (rawRecurring is int) {
      parsedIsRecurring = rawRecurring == 1;
    }

    return TransactionModel(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      amount: (map['amount'] as num).toDouble(),
      currency: AppCurrencyExtension.fromString(map['currency'] as String?),
      type: TransactionTypeExtension.fromString(map['type'] as String?),
      categoryId: (map['category_id'] ?? map['categoryId']) as String? ?? 'general',
      categoryName: (map['category_name'] ?? map['categoryName']) as String? ?? 'عام',
      categoryIconCode: (map['category_icon_code'] ?? map['categoryIconCode']) as int? ?? 0xe5d8,
      categoryColorValue: (map['category_color_value'] ?? map['categoryColorValue']) as int? ?? 0xFF0D9488,
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      notes: map['notes'] as String?,
      createdAt: DateTime.tryParse((map['created_at'] ?? map['createdAt']) as String? ?? '') ?? DateTime.now(),
      walletId: walletId,
      isTransfer: parsedIsTransfer,
      transferId: (map['transfer_id'] ?? map['transferId']) as String?,
      exchangeRate: ((map['exchange_rate'] ?? map['exchangeRate']) as num?)?.toDouble(),
      targetCurrency: (map['target_currency'] ?? map['targetCurrency']) != null
          ? AppCurrencyExtension.fromString((map['target_currency'] ?? map['targetCurrency']) as String)
          : null,
      targetAmount: ((map['target_amount'] ?? map['targetAmount']) as num?)?.toDouble(),
      isRecurring: parsedIsRecurring,
      recurringId: (map['recurring_id'] ?? map['recurringId']) as String?,
    );
  }

  TransactionModel copyWith({
    String? id,
    String? title,
    double? amount,
    AppCurrency? currency,
    TransactionType? type,
    String? categoryId,
    String? categoryName,
    int? categoryIconCode,
    int? categoryColorValue,
    DateTime? date,
    String? notes,
    DateTime? createdAt,
    int? walletId,
    int? isTransfer,
    String? transferId,
    double? exchangeRate,
    AppCurrency? targetCurrency,
    double? targetAmount,
    bool? isRecurring,
    String? recurringId,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryIconCode: categoryIconCode ?? this.categoryIconCode,
      categoryColorValue: categoryColorValue ?? this.categoryColorValue,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      walletId: walletId ?? this.walletId,
      isTransfer: isTransfer ?? this.isTransfer,
      transferId: transferId ?? this.transferId,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      targetCurrency: targetCurrency ?? this.targetCurrency,
      targetAmount: targetAmount ?? this.targetAmount,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringId: recurringId ?? this.recurringId,
    );
  }
}
