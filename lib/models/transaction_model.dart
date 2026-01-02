class TransactionModel {
  final int? id;
  final String name;
  final String concept;
  final double amount;
  final bool isPositive;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;

  TransactionModel({
    this.id,
    required this.name,
    required this.concept,
    required this.amount,
    required this.isPositive,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id']?.toInt(),
      name: map['name'] ?? '',
      concept: map['concept'] ?? '',
      amount: map['amount']?.toDouble() ?? 0.0,
      isPositive: map['is_positive'] == 1,
      date: DateTime.parse(map['date']),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'concept': concept,
      'amount': amount,
      'is_positive': isPositive ? 1 : 0,
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  TransactionModel copyWith({
    int? id,
    String? name,
    String? concept,
    double? amount,
    bool? isPositive,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      concept: concept ?? this.concept,
      amount: amount ?? this.amount,
      isPositive: isPositive ?? this.isPositive,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get formattedAmount {
    final sign = isPositive ? '+' : '-';
    return '$sign\$${amount.toStringAsFixed(2)}';
  }

  @override
  String toString() {
    return 'TransactionModel(id: $id, name: $name, concept: $concept, amount: $amount, isPositive: $isPositive, date: $date)';
  }
}
