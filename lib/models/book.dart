class Book {
  final int id;
  final int accountId;
  final String name;
  final DateTime createdAt;

  Book({
    required this.id,
    required this.accountId,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountId': accountId,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Book.fromJson(Map<String, dynamic> json) => Book(
        id: json['id'] as int,
        accountId: json['accountId'] as int,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
