import 'package:backend/src/http/responses.dart';
import 'package:dart_frog/dart_frog.dart';

/// Health check / service banner.
Response onRequest(RequestContext context) {
  return ok({
    'service': 'Lead Management Platform API',
    'status': 'ok',
    'docs': 'See README.md for API documentation',
  });
}
