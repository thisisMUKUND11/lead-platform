import 'package:backend/src/auth/lead_access.dart';
import 'package:backend/src/db/database.dart';
import 'package:backend/src/http/api_exception.dart';
import 'package:backend/src/http/guards.dart';
import 'package:backend/src/http/request_helpers.dart';
import 'package:backend/src/http/responses.dart';
import 'package:backend/src/models/lead.dart';
import 'package:backend/src/repositories/lead_repository.dart';
import 'package:backend/src/services/lead_service.dart';
import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  return switch (context.request.method) {
    HttpMethod.get => _get(context, id),
    HttpMethod.patch => _patch(context, id),
    HttpMethod.delete => _delete(context, id),
    _ => throw ApiException(405, 'Method not allowed', code: 'method_not_allowed'),
  };
}

/// GET /leads/:id
Future<Response> _get(RequestContext context, String id) async {
  final principal = requireAuth(context);
  final result = await loadAccessibleLead(context, id, principal: principal);
  return ok({'lead': result.lead.toJson()});
}

/// PATCH /leads/:id — update fields (incl. status). Members may edit only
/// leads assigned to them; admins any. Reassignment is a separate endpoint.
Future<Response> _patch(RequestContext context, String id) async {
  final principal = requireAuth(context);
  final result = await loadAccessibleLead(context, id, principal: principal);
  final body = await readJsonBody(context);

  final fields = <String, Object?>{};
  for (final key in ['name', 'email', 'phone', 'company', 'source', 'status']) {
    if (body.containsKey(key)) fields[key] = (body[key] as String?)?.trim();
  }
  if (fields.isEmpty) {
    throw ApiException.badRequest('No updatable fields provided');
  }
  final status = fields['status'];
  if (status != null && !LeadStatus.isValid(status as String)) {
    throw ApiException.badRequest(
      'Invalid status. Allowed: ${LeadStatus.values.map((s) => s.wire).join(', ')}',
    );
  }

  final updated = await context.read<LeadService>().updateLead(
        current: result.lead,
        fields: fields,
        actorId: principal.userId,
      );
  return ok({'lead': updated.toJson()});
}

/// DELETE /leads/:id — admin only.
Future<Response> _delete(RequestContext context, String id) async {
  requireAdmin(context);
  final db = context.read<Database>();
  final repo = LeadRepository(db.session);
  final lead = await repo.findById(id);
  if (lead == null) {
    throw ApiException.notFound('Lead not found');
  }
  await repo.delete(id);
  return noContent();
}
