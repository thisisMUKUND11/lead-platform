/// An error that maps directly to an HTTP status code and JSON error body.
///
/// Handlers throw these; the global middleware catches them and renders a
/// consistent `{ "error": { ... } }` envelope with the right status code.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.code});

  final int statusCode;
  final String message;
  final String? code;

  factory ApiException.badRequest(String message, {String? code}) =>
      ApiException(400, message, code: code ?? 'bad_request');

  factory ApiException.unauthorized([String message = 'Authentication required']) =>
      ApiException(401, message, code: 'unauthorized');

  factory ApiException.forbidden([String message = 'You do not have permission to perform this action']) =>
      ApiException(403, message, code: 'forbidden');

  factory ApiException.notFound([String message = 'Resource not found']) =>
      ApiException(404, message, code: 'not_found');

  factory ApiException.conflict(String message) =>
      ApiException(409, message, code: 'conflict');

  Map<String, dynamic> toJson() => {
        'error': {
          'message': message,
          if (code != null) 'code': code,
        },
      };
}
