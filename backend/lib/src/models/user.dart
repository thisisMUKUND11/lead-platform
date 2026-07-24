/// A user of the platform. Roles are [UserRole.admin] and [UserRole.member].
enum UserRole {
  admin,
  member;

  static UserRole fromString(String value) =>
      UserRole.values.firstWhere((r) => r.name == value);
}

class User {
  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
    this.passwordHash,
  });

  final String id;
  final String email;
  final String name;
  final UserRole role;
  final DateTime createdAt;

  /// Only populated when read for authentication; never serialized to JSON.
  final String? passwordHash;

  factory User.fromRow(Map<String, dynamic> row) {
    return User(
      id: row['id'].toString(),
      email: row['email'] as String,
      name: row['name'] as String,
      role: UserRole.fromString(row['role'] as String),
      createdAt: row['created_at'] as DateTime,
      passwordHash: row['password_hash'] as String?,
    );
  }

  bool get isAdmin => role == UserRole.admin;

  /// Public JSON representation — never includes the password hash.
  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role.name,
        'createdAt': createdAt.toIso8601String(),
      };
}
