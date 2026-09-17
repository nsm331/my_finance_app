class PersonModel {
  final String id;
  final String name;
  final String? phone;
  final String? notes;
  final DateTime createdAt;
  final String? userId;

  PersonModel({
    required this.id,
    required this.name,
    this.phone,
    this.notes,
    DateTime? createdAt,
    this.userId,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      if (userId != null && userId!.isNotEmpty) 'user_id': userId,
    };
  }

  Map<String, dynamic> toJson() => toMap();

  factory PersonModel.fromMap(Map<dynamic, dynamic> map) {
    final dateStr = (map['created_at'] ?? map['createdAt']) as String?;
    return PersonModel(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'بدون اسم',
      phone: map['phone'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.tryParse(dateStr ?? '') ?? DateTime.now(),
      userId: (map['user_id'] ?? map['userId']) as String?,
    );
  }

  factory PersonModel.fromJson(Map<dynamic, dynamic> json) => PersonModel.fromMap(json);

  PersonModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? notes,
    DateTime? createdAt,
    String? userId,
  }) {
    return PersonModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
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
