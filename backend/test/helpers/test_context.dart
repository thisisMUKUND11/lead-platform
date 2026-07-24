import 'dart:convert';

import 'package:backend/src/auth/auth_principal.dart';
import 'package:backend/src/auth/jwt_service.dart';
import 'package:backend/src/db/database.dart';
import 'package:backend/src/services/lead_service.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';

class _MockRequestContext extends Mock implements RequestContext {}

/// Builds a [RequestContext] wired with a real [Request] and the dependencies
/// the middleware would normally inject, so route handlers can be invoked
/// directly in tests. [principal] simulates the authenticated user (null =
/// unauthenticated request).
RequestContext buildTestContext({
  required Database db,
  required JwtService jwt,
  String method = 'POST',
  String path = '/',
  Map<String, String> query = const {},
  Object? jsonBody,
  AuthPrincipal? principal,
}) {
  final uri = Uri(
    scheme: 'http',
    host: 'localhost',
    path: path,
    queryParameters: query.isEmpty ? null : query,
  );
  final request = Request(
    method,
    uri,
    body: jsonBody == null ? null : jsonEncode(jsonBody),
    headers: {'Content-Type': 'application/json'},
  );

  final context = _MockRequestContext();
  when(() => context.request).thenReturn(request);
  when(() => context.read<Database>()).thenReturn(db);
  when(() => context.read<JwtService>()).thenReturn(jwt);
  when(() => context.read<LeadService>()).thenReturn(LeadService(db));
  when(() => context.read<AuthPrincipal?>()).thenReturn(principal);
  return context;
}
