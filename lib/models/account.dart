class Account {
  final int id;
  final String username;
  final String passwordHash;
  final DateTime createdAt;

  Account({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'passwordHash': passwordHash,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as int,
        username: json['username'] as String,
        passwordHash: json['passwordHash'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
