import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Thin HTTP wrapper around the backend JSON API.
///
/// Holds the bearer [token] (set after login) and attaches it to every
/// request. Decodes JSON responses and converts non-2xx responses into
/// [ApiException]s carrying the server's error message + code.
class ApiClient {
  ApiClient(this.baseUrl, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  String? token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> get(String path, {Map<String, String>? query}) {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: query?.isEmpty ?? true ? null : query,
    );
    return _send(() => _http.get(uri, headers: _headers));
  }

  Future<dynamic> post(String path, {Object? body}) {
    final uri = Uri.parse('$baseUrl$path');
    return _send(
      () => _http.post(uri, headers: _headers, body: jsonEncode(body ?? {})),
    );
  }

  Future<dynamic> patch(String path, {Object? body}) {
    final uri = Uri.parse('$baseUrl$path');
    return _send(
      () => _http.patch(uri, headers: _headers, body: jsonEncode(body ?? {})),
    );
  }

  Future<dynamic> delete(String path) {
    final uri = Uri.parse('$baseUrl$path');
    return _send(() => _http.delete(uri, headers: _headers));
  }

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    // Retry on network failure — the free-tier backend may be cold-starting
    // (waking from sleep), which can drop the first request or two.
    http.Response? response;
    const delays = [Duration(seconds: 2), Duration(seconds: 4)];
    for (var attempt = 0; ; attempt++) {
      try {
        response = await request();
        break;
      } catch (_) {
        if (attempt >= delays.length) {
          throw const ApiException(
            0,
            'Network error: unable to reach the server',
          );
        }
        await Future<void>.delayed(delays[attempt]);
      }
    }

    // Decode defensively: a proxy or cold-start page may return non-JSON.
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    // Error envelope: { "error": { "message": ..., "code": ... } }
    String message = 'Request failed (${response.statusCode})';
    String? code;
    if (decoded is Map && decoded['error'] is Map) {
      final error = decoded['error'] as Map;
      message = (error['message'] as String?) ?? message;
      code = error['code'] as String?;
    }
    throw ApiException(response.statusCode, message, code: code);
  }
}
