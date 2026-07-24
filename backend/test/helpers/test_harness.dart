import 'dart:io';

import 'package:backend/src/auth/jwt_service.dart';
import 'package:backend/src/auth/password.dart';
import 'package:backend/src/db/database.dart';
import 'package:backend/src/models/user.dart';
import 'package:backend/src/repositories/user_repository.dart';
import 'package:postgres/postgres.dart';

/// Shared integration-test harness: connects to a throwaway Postgres
/// (TEST_DATABASE_URL), applies the schema once, and truncates all tables
/// between tests so each test starts from a clean slate.
///
/// TEST_DATABASE_URL must point at a database you are happy to wipe.
/// In CI this is a Postgres service container; locally, a Docker container.
class TestHarness {
  TestHarness._(this.db, this.jwt);

  final Database db;
  final JwtService jwt;

  static String get _url {
    final url = Platform.environment['TEST_DATABASE_URL'];
    if (url == null || url.isEmpty) {
      throw StateError(
        'TEST_DATABASE_URL is not set. Point it at a disposable Postgres, e.g.\n'
        '  docker run -d -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=leadapp \\\n'
        '    -p 5433:5432 postgres:16\n'
        '  export TEST_DATABASE_URL=postgresql://postgres:postgres@localhost:5433/leadapp',
      );
    }
    return url;
  }

  static Future<TestHarness> start() async {
    final db = await Database.connect(_url);
    await _applySchema(db);
    final jwt = JwtService(secret: 'test-secret', expiresMinutes: 60);
    return TestHarness._(db, jwt);
  }

  static Future<void> _applySchema(Database db) async {
    final schema = File('db/schema.sql').readAsStringSync();
    await db.session.execute(schema, queryMode: QueryMode.simple);
  }

  /// Removes all data (respecting FKs) so the next test is isolated.
  Future<void> reset() async {
    await db.session.execute(
      'TRUNCATE activities, lead_notes, leads, users RESTART IDENTITY CASCADE',
      queryMode: QueryMode.simple,
    );
  }

  Future<void> dispose() => db.close();

  /// Creates a user directly (bypassing HTTP) for test setup.
  Future<User> createUser({
    required String email,
    required String name,
    required UserRole role,
    String password = 'Password123!',
  }) {
    return UserRepository(db.session).create(
      email: email,
      name: name,
      passwordHash: hashPassword(password),
      role: role,
    );
  }
}
