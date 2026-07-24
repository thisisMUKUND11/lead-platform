import 'dart:io';

import 'package:backend/src/config/env.dart';
import 'package:backend/src/db/database.dart';
import 'package:postgres/postgres.dart';

/// Applies db/schema.sql to the database in DATABASE_URL.
///
/// Usage (from the backend/ directory):
///   dart run bin/migrate.dart
Future<void> main() async {
  final schemaFile = File('db/schema.sql');
  if (!schemaFile.existsSync()) {
    stderr.writeln('Cannot find db/schema.sql — run this from backend/.');
    exit(1);
  }
  final schema = schemaFile.readAsStringSync();

  final endpoint = Database.parseEndpoint(Env.instance.databaseUrl);
  final conn = await Connection.open(
    endpoint,
    settings: ConnectionSettings(sslMode: Database.sslModeFor(endpoint)),
  );

  stdout.writeln('Applying schema to ${endpoint.host}...');
  // Simple query protocol allows multiple statements in one call.
  await conn.execute(schema, queryMode: QueryMode.simple);
  await conn.close();
  stdout.writeln('✓ Schema applied.');
}
