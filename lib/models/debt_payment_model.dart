class DebtPaymentModel {
  final String id;
  final String debtId;
  final double amount;
  final DateTime date;
  final String? note;
  final bool impactsBalance; // هل أثر على رصيد الخزينة/المحفظة كعملية مالية؟

  DebtPaymentModel({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.date,
    this.note,
    this.impactsBalance = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'debtId': debtId,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
      'impactsBalance': impactsBalance ? 1 : 0,
    };
  }

  factory DebtPaymentModel.fromMap(Map<dynamic, dynamic> map) {
    bool parsedImpactsBalance = false;
    final rawImpact = map['impactsBalance'];
    if (rawImpact is bool) {
      parsedImpactsBalance = rawImpact;
    } else if (rawImpact is int) {
      parsedImpactsBalance = rawImpact == 1;
    }

    return DebtPaymentModel(
      id: map['id'] as String,
      debtId: map['debtId'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      note: map['note'] as String?,
      impactsBalance: parsedImpactsBalance,
    );
  }
}
