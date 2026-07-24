import 'package:backend/src/auth/auth_principal.dart';
import 'package:backend/src/db/database.dart';
import 'package:backend/src/http/api_exception.dart';
import 'package:backend/src/http/guards.dart';
import 'package:backend/src/http/request_helpers.dart';
import 'package:backend/src/http/responses.dart';
import 'package:backend/src/models/lead.dart';
import 'package:backend/src/repositories/lead_repository.dart';
import 'package:backend/src/services/lead_service.dart';
import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  return switch (context.request.method) {
    HttpMethod.get => _list(context),
    HttpMethod.post => _create(context),
    _ => throw ApiException(405, 'Method not allowed', code: 'method_not_allowed'),
  };
}

/// GET /leads — paginated, filterable list.
/// Admins see all leads; members see only leads assigned to them.
Future<Response> _list(RequestContext context) async {
  final principal = requireAuth(context);
  final q = context.request.uri.queryParameters;
  final pagination = readPagination(context);

  final status = q['status'];
  if (status != null && !LeadStatus.isValid(status)) {
    throw ApiException.badRequest(
      'Invalid status. Allowed: ${LeadStatus.values.map((s) => s.wire).join(', ')}',
    );
  }

  // Members are always scoped to their own assigned leads, regardless of any
  // assigned_to query param they might try to pass.
  final assignedTo =
      principal.isAdmin ? q['assigned_to'] : principal.userId;

  final db = context.read<Database>();
  final page = await LeadRepository(db.session).list(
    filter: LeadFilter(
      status: status,
      assignedTo: assignedTo,
      source: q['source'],
      search: q['q'],
    ),
    page: pagination.page,
    limit: pagination.limit,
  );

  return ok(page.toJson((lead) => lead.toJson()));
}

/// POST /leads — public lead capture. No authentication required.
Future<Response> _create(RequestContext context) async {
  final body = await readJsonBody(context);
  final name = (body['name'] as String?)?.trim();
  final email = (body['email'] as String?)?.trim();

  if (name == null || name.isEmpty) {
    throw ApiException.badRequest('name is required');
  }
  if (email == null || !_looksLikeEmail(email)) {
    throw ApiException.badRequest('a valid email is required');
  }

  // If an authenticated user submits, attribute the lead to them; otherwise
  // it's an anonymous public submission.
  final principal = context.read<AuthPrincipal?>();

  final lead = await context.read<LeadService>().createLead(
        name: name,
        email: email,
        phone: (body['phone'] as String?)?.trim(),
        company: (body['company'] as String?)?.trim(),
        source: (body['source'] as String?)?.trim() ?? 'public_form',
        actorId: principal?.userId,
      );

  return created({'lead': lead.toJson()});
}

bool _looksLikeEmail(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
