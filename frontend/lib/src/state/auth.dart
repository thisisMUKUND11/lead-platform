import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/api_service.dart';
import '../config.dart';
import '../models.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(AppConfig.apiBaseUrl);
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref.watch(apiClientProvider));
});

/// Authentication state exposed to the UI and the router.
class AuthState {
  const AuthState({this.user, this.initializing = false});

  final User? user;

  /// True while we're restoring a persisted session on start-up.
  final bool initializing;

  bool get isAuthenticated => user != null;
  bool get isAdmin => user?.isAdmin ?? false;
}

/// Owns the current session: restores a persisted token, logs in/out, and
/// keeps the [ApiClient]'s bearer token in sync.
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._api, this._client)
      : super(const AuthState(initializing: true));

  final ApiService _api;
  final ApiClient _client;

  static const _tokenKey = 'auth_token';

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null) {
      state = const AuthState();
      return;
    }
    _client.token = token;
    try {
      final user = await _api.me();
      state = AuthState(user: user);
    } catch (_) {
      // Token invalid/expired — clear it.
      _client.token = null;
      await prefs.remove(_tokenKey);
      state = const AuthState();
    }
  }

  Future<void> login(String email, String password) async {
    final result = await _api.login(email, password);
    _client.token = result.token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, result.token);
    state = AuthState(user: result.user);
  }

  Future<void> logout() async {
    _client.token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    state = const AuthState();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final controller = AuthController(
    ref.watch(apiServiceProvider),
    ref.watch(apiClientProvider),
  );
  controller.restore();
  return controller;
});
