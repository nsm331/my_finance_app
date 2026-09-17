import 'dart:convert';
import 'app_currency.dart';
import 'debt_payment_model.dart';

enum DebtType {
  forMe, // دين لي (أنا دائن / سلفته)
  onMe,  // دين علي (أنا مدين / استلفت منه)
}

extension DebtTypeExtension on DebtType {
  String get nameAr {
    switch (this) {
      case DebtType.forMe:
        return 'دين لي (مستحق)';
      case DebtType.onMe:
        return 'دين علي (التزام)';
    }
  }

  String get shortLabel {
    switch (this) {
      case DebtType.forMe:
        return 'أطلب منه';
      case DebtType.onMe:
        return 'يطلب مني';
    }
  }

  static DebtType fromString(String? val) {
    if (val == 'onMe') return DebtType.onMe;
    return DebtType.forMe;
  }
}

class DebtModel {
  final String id;
  final String? personId;
  final String personName;
  final String? phone;
  final double totalAmount;
  final AppCurrency currency;
  final DebtType type;
  final DateTime? dueDate;
  final DateTime createdAt;
  final String? notes;
  final List<DebtPaymentModel> payments;
  final String? userId;

  DebtModel({
    required this.id,
    this.personId,
    required this.personName,
    this.phone,
    required this.totalAmount,
    required this.currency,
    required this.type,
    this.dueDate,
    DateTime? createdAt,
    this.notes,
    List<DebtPaymentModel>? payments,
    this.userId,
  })  : createdAt = createdAt ?? DateTime.now(),
        payments = payments ?? [];

  double get paidAmount {
    return payments.fold(0.0, (sum, p) => sum + p.amount);
  }

  double get remainingAmount {
    final rem = totalAmount - paidAmount;
    return rem > 0 ? rem : 0.0;
  }

  bool get isSettled => remainingAmount <= 0.001;
  bool get isFullyPaid => isSettled;

  double get progress {
    if (totalAmount <= 0) return 1.0;
    final p = paidAmount / totalAmount;
    return p.clamp(0.0, 1.0);
  }

  Map<String, dynamic> toMap() {
    final cleanPersonId = (personId != null && personId!.trim().isNotEmpty)
        ? personId!.trim()
        : null;
    return {
      'id': id,
      'person_id': cleanPersonId,
      'person_name': personName,
      'phone': phone,
      'total_amount': totalAmount,
      'currency': currency.code,
      'type': type.name,
      'due_date': dueDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'notes': notes,
      'payments': jsonEncode(payments.map((p) => p.toMap()).toList()),
      'payments_json': jsonEncode(payments.map((p) => p.toMap()).toList()),
      if (userId != null && userId!.isNotEmpty) 'user_id': userId,
    };
  }

  Map<String, dynamic> toJson() => toMap();

  factory DebtModel.fromMap(Map<dynamic, dynamic> map) {
    List<DebtPaymentModel> parsedPayments = [];
    final rawPayments = map['payments'] ?? map['payments_json'];
    if (rawPayments is String && rawPayments.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPayments);
        if (decoded is List) {
          parsedPayments = decoded
              .map((p) => DebtPaymentModel.fromMap(p as Map<dynamic, dynamic>))
              .toList();
        }
      } catch (_) {}
    } else if (rawPayments is List) {
      parsedPayments = rawPayments
          .map((p) => DebtPaymentModel.fromMap(p as Map<dynamic, dynamic>))
          .toList();
    }

    final rawPersonId = (map['person_id'] ?? map['personId']) as String?;
    final cleanPersonId = (rawPersonId != null && rawPersonId.trim().isNotEmpty)
        ? rawPersonId.trim()
        : null;

    return DebtModel(
      id: map['id'] as String,
      personId: cleanPersonId,
      personName: (map['person_name'] ?? map['personName']) as String? ?? 'بدون اسم',
      phone: map['phone'] as String?,
      totalAmount: ((map['total_amount'] ?? map['totalAmount']) as num).toDouble(),
      currency: AppCurrencyExtension.fromString(map['currency'] as String?),
      type: DebtTypeExtension.fromString(map['type'] as String?),
      dueDate: (map['due_date'] ?? map['dueDate']) != null
          ? DateTime.tryParse((map['due_date'] ?? map['dueDate']) as String)
          : null,
      createdAt: DateTime.tryParse((map['created_at'] ?? map['createdAt']) as String? ?? '') ?? DateTime.now(),
      notes: map['notes'] as String?,
      payments: parsedPayments,
      userId: (map['user_id'] ?? map['userId']) as String?,
    );
  }

  factory DebtModel.fromJson(Map<dynamic, dynamic> json) => DebtModel.fromMap(json);

  DebtModel copyWith({
    String? id,
    String? personId,
    String? personName,
    String? phone,
    double? totalAmount,
    AppCurrency? currency,
    DebtType? type,
    DateTime? dueDate,
    DateTime? createdAt,
    String? notes,
    List<DebtPaymentModel>? payments,
    String? userId,
  }) {
    return DebtModel(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      personName: personName ?? this.personName,
      phone: phone ?? this.phone,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      type: type ?? this.type,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
      payments: payments ?? List.from(this.payments),
      userId: userId ?? this.userId,
    );
  }
}
