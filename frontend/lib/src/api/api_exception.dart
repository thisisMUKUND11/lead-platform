/// An error returned by the API (non-2xx) or a network failure.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.message, {this.code});

  final int statusCode;
  final String message;
  final String? code;

  /// True when the user is not authenticated (expired/invalid token).
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}
