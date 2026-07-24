import 'package:backend/src/models/user.dart';
import 'package:postgres/postgres.dart';

class UserRepository {
  UserRepository(this.session);

  final Session session;

  Future<User?> findByEmail(String email) async {
    final result = await session.execute(
      Sql.named('SELECT * FROM users WHERE email = @email'),
      parameters: {'email': email.toLowerCase()},
    );
    if (result.isEmpty) return null;
    return User.fromRow(result.first.toColumnMap());
  }

  Future<User?> findById(String id) async {
    final result = await session.execute(
      Sql.named('SELECT * FROM users WHERE id = @id'),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return User.fromRow(result.first.toColumnMap());
  }

  Future<List<User>> listAll() async {
    final result = await session.execute(
      'SELECT * FROM users ORDER BY created_at ASC',
    );
    return result.map((r) => User.fromRow(r.toColumnMap())).toList();
  }

  Future<User> create({
    required String email,
    required String name,
    required String passwordHash,
    required UserRole role,
  }) async {
    final result = await session.execute(
      Sql.named('''
        INSERT INTO users (email, name, password_hash, role)
        VALUES (@email, @name, @hash, @role)
        RETURNING *
      '''),
      parameters: {
        'email': email.toLowerCase(),
        'name': name,
        'hash': passwordHash,
        'role': role.name,
      },
    );
    return User.fromRow(result.first.toColumnMap());
  }

  /// Updates a user's name, role and/or password hash. Only non-null fields
  /// are changed. Passwords are stored hashed and are never readable.
  Future<User> update(
    String id, {
    String? name,
    UserRole? role,
    String? passwordHash,
  }) async {
    final sets = <String>[];
    final params = <String, Object?>{'id': id};
    if (name != null) {
      sets.add('name = @name');
      params['name'] = name;
    }
    if (role != null) {
      sets.add('role = @role');
      params['role'] = role.name;
    }
    if (passwordHash != null) {
      sets.add('password_hash = @hash');
      params['hash'] = passwordHash;
    }
    if (sets.isEmpty) {
      final existing = await findById(id);
      return existing!;
    }
    final result = await session.execute(
      Sql.named('UPDATE users SET ${sets.join(', ')} WHERE id = @id RETURNING *'),
      parameters: params,
    );
    return User.fromRow(result.first.toColumnMap());
  }

  /// Number of admins — used to guard against deleting the last one.
  Future<int> adminCount() async {
    final result = await session.execute(
      "SELECT COUNT(*) AS n FROM users WHERE role = 'admin'",
    );
    return (result.first.toColumnMap()['n'] as int?) ?? 0;
  }

  Future<void> delete(String id) async {
    await session.execute(
      Sql.named('DELETE FROM users WHERE id = @id'),
      parameters: {'id': id},
    );
  }
}
