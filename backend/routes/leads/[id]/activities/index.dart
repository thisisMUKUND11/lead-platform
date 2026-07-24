import 'package:backend/src/auth/lead_access.dart';
import 'package:backend/src/db/database.dart';
import 'package:backend/src/http/guards.dart';
import 'package:backend/src/http/request_helpers.dart';
import 'package:backend/src/http/responses.dart';
import 'package:backend/src/repositories/activity_repository.dart';
import 'package:dart_frog/dart_frog.dart';

/// GET /leads/:id/activities — the lead's activity trail, newest first
/// (paginated).
Future<Response> onRequest(RequestContext context, String id) async {
  allowMethods(context, [HttpMethod.get]);
  final principal = requireAuth(context);
  await loadAccessibleLead(context, id, principal: principal);

  final pagination = readPagination(context, defaultLimit: 50);
  final db = context.read<Database>();
  final activities = await ActivityRepository(db.session).listForLead(
    id,
    page: pagination.page,
    limit: pagination.limit,
  );
  return ok(activities.toJson((a) => a.toJson()));
}
