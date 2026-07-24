import 'package:backend/src/config/env.dart';
import 'package:postgres/postgres.dart';

/// Thin wrapper around a pooled Postgres connection.
///
/// A single [Database] instance is created at server start-up and provided to
/// every request through Dart Frog middleware, so all requests share one
/// connection pool.
class Database {
  Database(this._pool);

  final Pool<void> _pool;

  /// The pooled session, usable directly for one-off (non-transactional)
  /// queries. Repositories accept a [Session] so the same code works against
  /// either this pool or a transaction opened via [transaction].
  Session get session => _pool;

  /// Builds a [Database] from a `postgresql://` connection URL.
  static Future<Database> connect(String url) async {
    final endpoint = parseEndpoint(url);
    final pool = Pool<void>.withEndpoints(
      [endpoint],
      settings: PoolSettings(
        maxConnectionCount: 8,
        // Supabase (and any hosted Postgres) requires TLS; local dev does not.
        sslMode: sslModeFor(endpoint),
      ),
    );
    // Fail fast if the credentials/host are wrong.
    await pool.execute('SELECT 1');
    return Database(pool);
  }

  /// Runs a parameterized query and returns the result rows.
  ///
  /// Use named parameters, e.g. `@id`, with the [parameters] map.
  Future<Result> execute(
    String sql, {
    Map<String, Object?> parameters = const {},
  }) {
    return _pool.execute(Sql.named(sql), parameters: parameters);
  }

  /// Runs [action] inside a single transaction.
  Future<T> transaction<T>(Future<T> Function(TxSession tx) action) {
    return _pool.runTx(action);
  }

  Future<void> close() => _pool.close();

  /// TLS is required for hosted Postgres (e.g. Supabase) and disabled for
  /// local development databases.
  static SslMode sslModeFor(Endpoint endpoint) {
    final isLocal =
        endpoint.host == 'localhost' || endpoint.host == '127.0.0.1';
    return isLocal ? SslMode.disable : SslMode.require;
  }

  /// Parses a `postgresql://user:pass@host:port/db` URL into an [Endpoint].
  static Endpoint parseEndpoint(String url) {
    final uri = Uri.parse(url);
    final userInfo = uri.userInfo.split(':');
    final username = Uri.decodeComponent(userInfo.first);
    final password =
        userInfo.length > 1 ? Uri.decodeComponent(userInfo[1]) : null;
    final database =
        uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
    return Endpoint(
      host: uri.host,
      port: uri.hasPort ? uri.port : 5432,
      database: database.isEmpty ? 'postgres' : database,
      username: username,
      password: password,
    );
  }
}

/// Convenience: build the app database from [Env].
Future<Database> openDatabaseFromEnv() =>
    Database.connect(Env.instance.databaseUrl);
