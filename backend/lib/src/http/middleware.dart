import 'package:backend/src/auth/auth_principal.dart';
import 'package:backend/src/auth/jwt_service.dart';
import 'package:backend/src/bootstrap.dart';
import 'package:backend/src/config/env.dart';
import 'package:backend/src/db/database.dart';
import 'package:backend/src/http/api_exception.dart';
import 'package:backend/src/http/responses.dart';
import 'package:backend/src/services/lead_service.dart';
import 'package:dart_frog/dart_frog.dart';

/// The application middleware stack, applied to every route.
///
/// Execution order (outermost first): error handler → CORS → dependency &
/// auth injection → route handler.
Handler appMiddleware(Handler handler) {
  return handler
      .use(_injectDependencies())
      .use(_cors())
      .use(_errorHandler());
}

/// Opens the DB, decodes the bearer token, and provides shared dependencies
/// (Database, JwtService, LeadService, and the nullable AuthPrincipal) to the
/// request context.
Middleware _injectDependencies() {
  return (handler) {
    return (context) async {
      final db = await database();
      final env = Env.instance;
      final jwt = JwtService(
        secret: env.jwtSecret,
        expiresMinutes: env.jwtExpiresMinutes,
      );
      final principal = _principalFromRequest(context, jwt);

      final injected = context
          .provide<Database>(() => db)
          .provide<JwtService>(() => jwt)
          .provide<LeadService>(() => LeadService(db))
          .provide<AuthPrincipal?>(() => principal);

      return handler(injected);
    };
  };
}

AuthPrincipal? _principalFromRequest(RequestContext context, JwtService jwt) {
  final header = context.request.headers['Authorization'] ??
      context.request.headers['authorization'];
  if (header == null || !header.startsWith('Bearer ')) return null;
  final token = header.substring(7).trim();
  if (token.isEmpty) return null;
  return jwt.verify(token);
}

/// Translates thrown [ApiException]s (and unexpected errors) into JSON
/// responses with the correct status code.
Middleware _errorHandler() {
  return (handler) {
    return (context) async {
      try {
        return await handler(context);
      } on ApiException catch (e) {
        return jsonResponse(e.statusCode, e.toJson());
      } catch (e, st) {
        // ignore: avoid_print
        print('Unhandled error: $e\n$st');
        return jsonResponse(500, {
          'error': {'message': 'Internal server error', 'code': 'internal'},
        });
      }
    };
  };
}

/// Adds permissive CORS headers so the Flutter web client can call the API,
/// and short-circuits preflight OPTIONS requests.
Middleware _cors() {
  return (handler) {
    return (context) async {
      final origin = _resolveOrigin(context);
      final corsHeaders = {
        'Access-Control-Allow-Origin': origin,
        'Access-Control-Allow-Methods': 'GET, POST, PATCH, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
        'Access-Control-Max-Age': '86400',
      };
      if (context.request.method == HttpMethod.options) {
        return Response(statusCode: 204, headers: corsHeaders);
      }
      final response = await handler(context);
      return response.copyWith(
        headers: {...response.headers, ...corsHeaders},
      );
    };
  };
}

String _resolveOrigin(RequestContext context) {
  final allowed = Env.instance.corsOrigins;
  if (allowed.contains('*')) return '*';
  final requestOrigin = context.request.headers['Origin'] ??
      context.request.headers['origin'];
  if (requestOrigin != null && allowed.contains(requestOrigin)) {
    return requestOrigin;
  }
  return allowed.first;
}
