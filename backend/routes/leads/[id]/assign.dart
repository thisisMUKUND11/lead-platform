import 'package:backend/src/db/database.dart';
import 'package:backend/src/http/api_exception.dart';
import 'package:backend/src/http/guards.dart';
import 'package:backend/src/http/request_helpers.dart';
import 'package:backend/src/http/responses.dart';
import 'package:backend/src/repositories/lead_repository.dart';
import 'package:backend/src/repositories/user_repository.dart';
import 'package:backend/src/services/lead_service.dart';
import 'package:dart_frog/dart_frog.dart';

/// POST /leads/:id/assign — assign (or unassign) a lead to a user.
/// Admin only. Body: { "userId": "<uuid>" | null }.
Future<Response> onRequest(RequestContext context, String id) async {
  allowMethods(context, [HttpMethod.post]);
  final principal = requireAdmin(context);

  final db = context.read<Database>();
  final lead = await LeadRepository(db.session).findById(id);
  if (lead == null) {
    throw ApiException.notFound('Lead not found');
  }

  final body = await readJsonBody(context);
  final userId = (body['userId'] as String?)?.trim();

  // Validate the assignee exists (null clears the assignment).
  if (userId != null && userId.isNotEmpty) {
    final assignee = await UserRepository(db.session).findById(userId);
    if (assignee == null) {
      throw ApiException.badRequest('Assignee user does not exist');
    }
  }

  final updated = await context.read<LeadService>().assignLead(
        leadId: id,
        userId: (userId != null && userId.isNotEmpty) ? userId : null,
        actorId: principal.userId,
      );
  return ok({'lead': updated.toJson()});
}
