class PersonModel {
  final String id;
  final String name;
  final String? phone;
  final String? notes;
  final DateTime createdAt;

  PersonModel({
    required this.id,
    required this.name,
    this.phone,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PersonModel.fromMap(Map<dynamic, dynamic> map) {
    final dateStr = (map['created_at'] ?? map['createdAt']) as String?;
    return PersonModel(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'بدون اسم',
      phone: map['phone'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.tryParse(dateStr ?? '') ?? DateTime.now(),
    );
  }

  PersonModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? notes,
    DateTime? createdAt,
  }) {
    return PersonModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersonModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PersonModel(id: $id, name: $name)';
}
