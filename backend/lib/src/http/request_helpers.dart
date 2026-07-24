import 'dart:convert';

import 'package:backend/src/http/api_exception.dart';
import 'package:dart_frog/dart_frog.dart';

/// Reads and decodes a JSON object request body, throwing 400 on malformed
/// input or a non-object payload.
Future<Map<String, dynamic>> readJsonBody(RequestContext context) async {
  final raw = await context.request.body();
  if (raw.isEmpty) return <String, dynamic>{};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException.badRequest('Request body must be a JSON object');
    }
    return decoded;
  } on FormatException {
    throw ApiException.badRequest('Invalid JSON in request body');
  }
}

/// Parsed pagination parameters, clamped to sane bounds.
class Pagination {
  const Pagination({required this.page, required this.limit});

  final int page;
  final int limit;
}

/// Reads `?page` and `?limit` query params with defaults and clamping.
Pagination readPagination(
  RequestContext context, {
  int defaultLimit = 20,
  int maxLimit = 100,
}) {
  final q = context.request.uri.queryParameters;
  var page = int.tryParse(q['page'] ?? '') ?? 1;
  var limit = int.tryParse(q['limit'] ?? '') ?? defaultLimit;
  if (page < 1) page = 1;
  if (limit < 1) limit = defaultLimit;
  if (limit > maxLimit) limit = maxLimit;
  return Pagination(page: page, limit: limit);
}
