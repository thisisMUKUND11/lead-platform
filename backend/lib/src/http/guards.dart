import 'package:backend/src/auth/auth_principal.dart';
import 'package:backend/src/http/api_exception.dart';
import 'package:dart_frog/dart_frog.dart';

/// Returns the authenticated principal or throws 401.
///
/// This is the single server-side gate for "must be logged in". The Flutter
/// client mirrors these rules to hide UI, but the server is authoritative.
AuthPrincipal requireAuth(RequestContext context) {
  final principal = context.read<AuthPrincipal?>();
  if (principal == null) {
    throw ApiException.unauthorized();
  }
  return principal;
}

/// Returns the authenticated principal if they are an admin, else throws
/// 401 (not logged in) or 403 (logged in but not an admin).
AuthPrincipal requireAdmin(RequestContext context) {
  final principal = requireAuth(context);
  if (!principal.isAdmin) {
    throw ApiException.forbidden();
  }
  return principal;
}

/// Rejects any HTTP method not in [allowed] with a 405.
void allowMethods(RequestContext context, List<HttpMethod> allowed) {
  if (!allowed.contains(context.request.method)) {
    throw ApiException(405, 'Method not allowed', code: 'method_not_allowed');
  }
}
