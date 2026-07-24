import 'package:backend/src/db/database.dart';

/// Cached single connection pool shared across all requests.
Future<Database>? _dbFuture;

/// Returns the process-wide [Database], opening it on first use.
Future<Database> database() => _dbFuture ??= openDatabaseFromEnv();

/// Test hook: inject a ready database and skip real connection setup.
void setDatabaseForTesting(Database db) {
  _dbFuture = Future.value(db);
}
