import 'package:backend/src/auth/lead_access.dart';
import 'package:backend/src/db/database.dart';
import 'package:backend/src/http/api_exception.dart';
import 'package:backend/src/http/guards.dart';
import 'package:backend/src/http/request_helpers.dart';
import 'package:backend/src/http/responses.dart';
import 'package:backend/src/repositories/note_repository.dart';
import 'package:backend/src/services/lead_service.dart';
import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  return switch (context.request.method) {
    HttpMethod.get => _list(context, id),
    HttpMethod.post => _create(context, id),
    _ => throw ApiException(405, 'Method not allowed', code: 'method_not_allowed'),
  };
}

/// GET /leads/:id/notes — timestamped notes, newest first (paginated).
Future<Response> _list(RequestContext context, String id) async {
  final principal = requireAuth(context);
  await loadAccessibleLead(context, id, principal: principal);
  final pagination = readPagination(context, defaultLimit: 50);
  final db = context.read<Database>();
  final notes = await NoteRepository(db.session).listForLead(
    id,
    page: pagination.page,
    limit: pagination.limit,
  );
  return ok(notes.toJson((n) => n.toJson()));
}

/// POST /leads/:id/notes — add a note (also appends to the activity trail).
Future<Response> _create(RequestContext context, String id) async {
  final principal = requireAuth(context);
  await loadAccessibleLead(context, id, principal: principal);

  final body = await readJsonBody(context);
  final text = (body['body'] as String?)?.trim();
  if (text == null || text.isEmpty) {
    throw ApiException.badRequest('body is required');
  }

  final note = await context.read<LeadService>().addNote(
        leadId: id,
        body: text,
        actorId: principal.userId,
      );
  return created({'note': note.toJson()});
}
