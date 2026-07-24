/// Application configuration.
///
/// The API base URL is injected at build/run time with
/// `--dart-define=API_BASE_URL=https://...`. It defaults to the local
/// Dart Frog dev server.
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
}
