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
}
