import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';

/// Builds a JSON [Response] with the given [statusCode] and [body].
Response jsonResponse(int statusCode, Object? body) {
  return Response(
    statusCode: statusCode,
    body: jsonEncode(body),
    headers: {'Content-Type': 'application/json'},
  );
}

Response ok(Object? body) => jsonResponse(200, body);

Response created(Object? body) => jsonResponse(201, body);

Response noContent() => Response(statusCode: 204);
