import 'dart:io';

import 'package:dotenv/dotenv.dart';

/// Application configuration, read from a local `.env` file (development)
/// and/or real process environment variables (production, e.g. Fly.io).
///
/// Process environment variables take precedence over the `.env` file.
class Env {
  Env._({
    required this.databaseUrl,
    required this.jwtSecret,
    required this.jwtExpiresMinutes,
    required this.port,
    required this.corsOrigins,
  });

  final String databaseUrl;
  final String jwtSecret;
  final int jwtExpiresMinutes;
  final int port;

  /// Allowed CORS origins. A single `*` means allow any origin.
  final List<String> corsOrigins;

  static Env? _instance;

  /// Loads configuration once and caches it.
  static Env get instance => _instance ??= _load();

  /// Test hook: override the loaded config.
  static set instance(Env env) => _instance = env;

  static Env _load() {
    final dotEnv = DotEnv(includePlatformEnvironment: true);
    // load() silently ignores a missing .env file, which is what we want
    // in production where variables come from the process environment.
    if (File('.env').existsSync()) {
      dotEnv.load();
    } else {
      dotEnv.load(); // still pulls in platform environment
    }

    String? read(String key) {
      final v = dotEnv[key] ?? Platform.environment[key];
      return (v == null || v.isEmpty) ? null : v;
    }

    final databaseUrl = read('DATABASE_URL');
    if (databaseUrl == null) {
      throw StateError(
        'DATABASE_URL is not set. Copy backend/.env.example to backend/.env '
        'and fill in your Supabase connection string.',
      );
    }

    final origins = (read('CORS_ORIGINS') ?? '*')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return Env._(
      databaseUrl: databaseUrl,
      jwtSecret: read('JWT_SECRET') ?? 'insecure-dev-secret',
      jwtExpiresMinutes: int.tryParse(read('JWT_EXPIRES_MINUTES') ?? '') ?? 720,
      port: int.tryParse(read('PORT') ?? '') ?? 8080,
      corsOrigins: origins.isEmpty ? ['*'] : origins,
    );
  }
}
