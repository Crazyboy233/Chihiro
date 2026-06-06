class Transaction {
  int? id;
  String type;
  int categoryId;
  double amount;
  String date;
  String? categoryNote;
  String? note;
  String createdAt;
  String updatedAt;

  Transaction({
    this.id,
    required this.type,
    required this.categoryId,
    required this.amount,
    required this.date,
    this.categoryNote,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'category_id': categoryId,
      'amount': amount,
      'date': date,
      'category_note': categoryNote,
      'note': note,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      type: map['type'],
      categoryId: map['category_id'],
      amount: map['amount'],
      date: map['date'],
      categoryNote: map['category_note'],
      note: map['note'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }

  Transaction copyWith({
    int? id,
    String? type,
    int? categoryId,
    double? amount,
    String? date,
    String? categoryNote,
    String? note,
    String? createdAt,
    String? updatedAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      categoryNote: categoryNote ?? this.categoryNote,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
